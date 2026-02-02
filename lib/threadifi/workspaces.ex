defmodule Threadifi.Workspaces do
  @moduledoc """
  The Workspaces context.
  """

  import Ecto.Query, warn: false
  alias Threadifi.Repo

  alias Threadifi.Accounts.User
  alias Threadifi.Workspaces.{Channel, ChannelMembership, Workspace}

  def list_workspaces do
    Repo.all(Workspace)
  end

  def get_workspace_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Workspace, slug: slug)
  end

  def create_workspace(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def list_channels(%Workspace{id: workspace_id}) do
    list_channels(workspace_id)
  end

  def list_channels(workspace_id) when is_integer(workspace_id) do
    Channel
    |> where([c], c.workspace_id == ^workspace_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  def create_channel(%Workspace{id: workspace_id}, attrs) do
    attrs = Map.put(attrs, :workspace_id, workspace_id)

    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
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

  def join_channel(%Channel{id: channel_id}, %User{id: user_id}, role \\ :member) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(%{channel_id: channel_id, user_id: user_id, role: role})
    |> Repo.insert()
  end

  def leave_channel(%Channel{id: channel_id}, %User{id: user_id}) do
    ChannelMembership
    |> where([m], m.channel_id == ^channel_id and m.user_id == ^user_id)
    |> Repo.delete_all()
  end
end
