defmodule Threadifi.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Threadifi.Repo

  alias Threadifi.Accounts.User
  alias Threadifi.Chat.{Message, MessageReaction, Snippet}
  alias Threadifi.Workspaces.Channel

  def list_messages(channel_id, opts \\ [])

  def list_messages(%Channel{id: channel_id}, opts), do: list_messages(channel_id, opts)

  def list_messages(channel_id, opts) when is_integer(channel_id) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    Message
    |> where([m], m.channel_id == ^channel_id)
    |> maybe_before(before)
    |> order_by([m], asc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def create_message(%User{id: user_id}, %Channel{id: channel_id}, attrs) do
    attrs = normalize_message_attrs(attrs, user_id, channel_id, :text)

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} -> {:ok, Repo.preload(message, :user)}
      {:error, changeset} -> {:error, changeset}
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
    |> Repo.transaction()
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
end
