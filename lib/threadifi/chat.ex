defmodule Threadifi.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Threadifi.Repo

  alias Threadifi.Accounts.{Scope, User}
  alias Threadifi.Chat.{Mention, Message, MessageReaction, PinnedMessage, Snippet}
  alias Threadifi.Workspaces.Channel

  def list_messages(channel_id, opts \\ [])

  def list_messages(%Channel{id: channel_id}, opts), do: list_messages(channel_id, opts)

  def list_messages(channel_id, opts) when is_integer(channel_id) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    Message
    |> where([m], m.channel_id == ^channel_id)
    |> where([m], is_nil(m.parent_message_id))
    |> maybe_before(before)
    |> order_by([m], asc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user, :snippet, :mentions, :reactions])
    |> Repo.all()
  end

  def create_message(%User{id: user_id}, %Channel{id: channel_id}, attrs) do
    attrs = normalize_message_attrs(attrs, user_id, channel_id, :text)

    Multi.new()
    |> Multi.insert(:message, Message.changeset(%Message{}, attrs))
    |> Multi.run(:mentions, fn repo, %{message: message} ->
      body = Map.get(attrs, :body) || Map.get(attrs, "body") || ""
      create_mentions_for_message(repo, message, body)
    end)
    |> Multi.run(:message_with_assocs, fn repo, %{message: message} ->
      {:ok, repo.preload(message, [:user, :snippet, :mentions])}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message_with_assocs: message}} -> {:ok, message}
      {:error, :message, changeset, _} -> {:error, changeset}
      {:error, :mentions, changeset, _} -> {:error, changeset}
      {:error, :message_with_assocs, reason, _} -> {:error, reason}
    end
  end

  def create_snippet_message(%User{} = user, %Channel{} = channel, attrs) do
    message_attrs = Map.get(attrs, :message, %{})
    snippet_attrs = Map.get(attrs, :snippet, attrs)

    Multi.new()
    |> Multi.insert(
      :message,
      Message.changeset(
        %Message{},
        normalize_message_attrs(message_attrs, user.id, channel.id, :snippet)
      )
    )
    |> Multi.insert(:snippet, fn %{message: message} ->
      Snippet.changeset(%Snippet{}, Map.put(snippet_attrs, :message_id, message.id))
    end)
    |> Multi.run(:mentions, fn repo, %{message: message} ->
      body = Map.get(message_attrs, :body) || Map.get(message_attrs, "body") || ""
      create_mentions_for_message(repo, message, body)
    end)
    |> Multi.run(:message_with_assocs, fn repo, %{message: message} ->
      {:ok, repo.preload(message, [:user, :snippet, :mentions])}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message_with_assocs: message}} -> {:ok, message}
      {:error, :message, changeset, _} -> {:error, changeset}
      {:error, :snippet, changeset, _} -> {:error, changeset}
      {:error, :mentions, changeset, _} -> {:error, changeset}
      {:error, :message_with_assocs, reason, _} -> {:error, reason}
    end
  end

  def get_message!(id) do
    Message
    |> where([m], m.id == ^id)
    |> preload([:user, :snippet, :reactions])
    |> Repo.one!()
  end

  def list_thread_messages(parent_message_id) when is_integer(parent_message_id) do
    Message
    |> where([m], m.parent_message_id == ^parent_message_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload([:user, :snippet, :mentions, :reactions])
    |> Repo.all()
  end

  def get_message_with_assocs!(id) do
    Message
    |> where([m], m.id == ^id)
    |> preload([:user, :snippet, :mentions, :reactions])
    |> Repo.one!()
  end

  def search_workspace(%Scope{user: %User{id: user_id}}, workspace_id, query) do
    query = String.trim(query || "")

    if query == "" do
      []
    else
      pattern = "%#{query}%"

      Message
      |> join(:inner, [m], c in assoc(m, :channel))
      |> join(:inner, [m, c], u in assoc(m, :user))
      |> join(:inner, [m, c, u], w in assoc(c, :workspace))
      |> join(:left, [m], s in assoc(m, :snippet))
      |> where([m, c, _u, w], w.id == ^workspace_id and w.owner_user_id == ^user_id)
      |> where(
        [m, _c, _u, _w, s],
        ilike(m.body, ^pattern) or ilike(s.title, ^pattern) or ilike(s.code, ^pattern)
      )
      |> preload([m, c, u, _w, s], user: u, channel: c, snippet: s)
      |> order_by([m], desc: m.inserted_at)
      |> limit(50)
      |> Repo.all()
      |> group_search_results()
    end
  end

  def list_pinned_messages(channel_id) when is_integer(channel_id) do
    PinnedMessage
    |> where([p], p.channel_id == ^channel_id)
    |> join(:inner, [p], m in assoc(p, :message))
    |> join(:inner, [p, m], u in assoc(m, :user))
    |> join(:left, [p, m, u], s in assoc(m, :snippet))
    |> preload([p, m, u, s], message: {m, [user: u, snippet: s]})
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def pin_message(%Scope{user: %User{id: user_id}}, channel_id, message_id) do
    %PinnedMessage{}
    |> PinnedMessage.changeset(%{})
    |> Ecto.Changeset.put_change(:channel_id, channel_id)
    |> Ecto.Changeset.put_change(:message_id, message_id)
    |> Ecto.Changeset.put_change(:pinned_by_user_id, user_id)
    |> Ecto.Changeset.validate_required([:channel_id, :message_id, :pinned_by_user_id])
    |> Repo.insert(on_conflict: :nothing)
  end

  def unpin_message(channel_id, message_id) do
    PinnedMessage
    |> where([p], p.channel_id == ^channel_id and p.message_id == ^message_id)
    |> Repo.delete_all()
  end

  defp group_search_results(messages) do
    messages
    |> Enum.group_by(& &1.channel_id)
    |> Enum.map(fn {_channel_id, group} ->
      channel = group |> List.first() |> Map.fetch!(:channel)
      %{channel: channel, messages: group}
    end)
    |> Enum.sort_by(
      fn %{messages: messages} ->
        messages |> List.first() |> Map.fetch!(:inserted_at)
      end,
      :desc
    )
  end

  def list_mentions_for_user(%Scope{user: %User{id: user_id}}) do
    Mention
    |> where([m], m.mentioned_user_id == ^user_id)
    |> join(:inner, [m], msg in assoc(m, :message))
    |> join(:inner, [m, msg], ch in assoc(msg, :channel))
    |> join(:inner, [m, msg, ch], w in assoc(ch, :workspace))
    |> preload([m, msg, ch, w], message: {msg, [:user, :snippet, channel: {ch, :workspace}]})
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  def extract_mentions(body) when is_binary(body) do
    body
    |> then(&Regex.scan(~r/(?:^|\s)@([\w\.-]{1,32})/, &1))
    |> Enum.map(fn [_, username] -> String.downcase(username) end)
    |> Enum.uniq()
  end

  def toggle_reaction(%User{id: user_id}, %Message{id: message_id}, emoji)
      when is_binary(emoji) do
    case Repo.get_by(MessageReaction, message_id: message_id, user_id: user_id, emoji: emoji) do
      nil ->
        %MessageReaction{}
        |> MessageReaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji
        })
        |> Repo.insert()

      reaction ->
        Repo.delete(reaction)
    end
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, %DateTime{} = before) do
    where(query, [m], m.inserted_at < ^before)
  end

  defp maybe_before(query, %NaiveDateTime{} = before) do
    where(query, [m], m.inserted_at < ^before)
  end

  defp normalize_message_attrs(attrs, user_id, channel_id, format) do
    %{
      channel_id: channel_id,
      user_id: user_id,
      body: fetch_attr(attrs, :body, "body"),
      format: fetch_attr(attrs, :format, "format") || format,
      parent_message_id: fetch_attr(attrs, :parent_message_id, "parent_message_id")
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp fetch_attr(attrs, atom_key, string_key) do
    Map.get(attrs, atom_key) || Map.get(attrs, string_key)
  end

  defp create_mentions_for_message(repo, message, body) do
    usernames = extract_mentions(body)

    if usernames == [] do
      {:ok, []}
    else
      users =
        User
        |> where([u], fragment("lower(split_part(?, '@', 1))", u.email) in ^usernames)
        |> repo.all()

      rows =
        Enum.map(users, fn user ->
          %{
            message_id: message.id,
            mentioned_user_id: user.id,
            inserted_at: DateTime.utc_now(:second),
            updated_at: DateTime.utc_now(:second)
          }
        end)

      {_, _} = repo.insert_all(Mention, rows, on_conflict: :nothing)
      {:ok, rows}
    end
  end
end
