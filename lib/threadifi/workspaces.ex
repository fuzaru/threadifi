defmodule Threadifi.Workspaces do
  @moduledoc """
  The Workspaces context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Threadifi.Repo

  alias Threadifi.Accounts.{Scope, User}
  alias Threadifi.Workspaces.{Channel, ChannelMembership, Workspace}

  def list_workspaces do
    Repo.all(Workspace)
  end

  def list_workspaces(%Scope{user: %User{id: user_id}}) do
    Workspace
    |> where([w], w.owner_user_id == ^user_id)
    |> order_by([w], asc: w.name)
    |> Repo.all()
  end

  def get_workspace_by_slug(slug) when is_binary(slug), do: Repo.get_by(Workspace, slug: slug)

  def get_workspace_by_slug(%Scope{user: %User{id: user_id}}, slug) when is_binary(slug) do
    Repo.get_by(Workspace, slug: slug, owner_user_id: user_id)
  end

  def create_workspace(attrs), do: Workspace.changeset(%Workspace{}, attrs) |> Repo.insert()

  def create_workspace(%Scope{user: %User{id: user_id}}, attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Ecto.Changeset.put_change(:owner_user_id, user_id)
    |> Ecto.Changeset.validate_required([:owner_user_id])
    |> Repo.insert()
  end

  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    Workspace.changeset(workspace, attrs)
  end

  def list_channels(%Workspace{id: workspace_id}), do: list_channels(workspace_id)

  def list_channels(workspace_id) when is_integer(workspace_id) do
    Channel
    |> where([c], c.workspace_id == ^workspace_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  def list_channels(%Scope{user: %User{id: user_id}}, %Workspace{id: workspace_id}) do
    Channel
    |> where([c], c.workspace_id == ^workspace_id)
    |> join(:left, [c], m in ChannelMembership,
      on: m.channel_id == c.id and m.user_id == ^user_id
    )
    |> where([c, m], c.type == :public or not is_nil(m.id))
    |> order_by([c], asc: c.inserted_at)
    |> select([c], c)
    |> Repo.all()
  end

  def create_channel(%Workspace{id: workspace_id}, attrs) do
    created_by_user_id =
      Map.get(attrs, :created_by_user_id) || Map.get(attrs, "created_by_user_id")

    %Channel{}
    |> Channel.changeset(attrs)
    |> Ecto.Changeset.put_change(:workspace_id, workspace_id)
    |> Ecto.Changeset.put_change(:created_by_user_id, created_by_user_id)
    |> Ecto.Changeset.validate_required([:workspace_id, :created_by_user_id])
    |> Repo.insert()
  end

  def create_channel(%Scope{user: %User{id: user_id}}, %Workspace{id: workspace_id}, attrs) do
    Multi.new()
    |> Multi.insert(
      :channel,
      %Channel{}
      |> Channel.changeset(attrs)
      |> Ecto.Changeset.put_change(:workspace_id, workspace_id)
      |> Ecto.Changeset.put_change(:created_by_user_id, user_id)
      |> Ecto.Changeset.validate_required([:workspace_id, :created_by_user_id])
    )
    |> Multi.insert(:membership, fn %{channel: channel} ->
      %ChannelMembership{}
      |> ChannelMembership.changeset(%{role: :admin})
      |> Ecto.Changeset.put_change(:channel_id, channel.id)
      |> Ecto.Changeset.put_change(:user_id, user_id)
      |> Ecto.Changeset.validate_required([:channel_id, :user_id])
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{channel: channel}} -> {:ok, channel}
      {:error, :channel, changeset, _} -> {:error, changeset}
      {:error, :membership, changeset, _} -> {:error, changeset}
    end
  end

  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  def get_channel_membership(%Channel{id: channel_id}, %User{id: user_id}) do
    Repo.get_by(ChannelMembership, channel_id: channel_id, user_id: user_id)
  end

  def member?(channel, user) do
    not is_nil(get_channel_membership(channel, user))
  end

  def member_role(channel, user) do
    case get_channel_membership(channel, user) do
      %ChannelMembership{role: role} -> role
      nil -> nil
    end
  end

  def join_channel(channel, user, role \\ :member)

  def join_channel(%Channel{id: channel_id}, %User{id: user_id}, role) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(%{role: role})
    |> Ecto.Changeset.put_change(:channel_id, channel_id)
    |> Ecto.Changeset.put_change(:user_id, user_id)
    |> Ecto.Changeset.validate_required([:channel_id, :user_id])
    |> Repo.insert()
  end

  def join_channel(%Scope{user: %User{} = user}, %Channel{} = channel, role) do
    join_channel(channel, user, role)
  end

  def leave_channel(%Channel{id: channel_id}, %User{id: user_id}) do
    ChannelMembership
    |> where([m], m.channel_id == ^channel_id and m.user_id == ^user_id)
    |> Repo.delete_all()
  end

  def leave_channel(%Scope{user: %User{} = user}, %Channel{} = channel) do
    leave_channel(channel, user)
  end
end
