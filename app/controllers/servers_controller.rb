class ServersController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server,
                only: %i[show edit update destroy settings settings_general settings_invite settings_danger
                         settings_channels settings_permissions update_permissions settings_members remove_member
                         settings_integrations update_jait_integration members]
  before_action :require_membership!, only: %i[show members]
  before_action :require_admin!,
                only: %i[settings settings_general settings_invite settings_danger settings_channels
                         settings_permissions update_permissions settings_members remove_member
                         settings_integrations update_jait_integration edit update]
  before_action :require_owner!, only: [:destroy]

  def index
    @servers = Current.user.servers
  end

  def new
    @server = Server.new
  end

  def create
    @server = Servers::CreateService.call(user: Current.user, params: server_params)
    redirect_to server_path(@server), notice: 'Server created!'
  rescue ActiveRecord::RecordInvalid => e
    @server = e.record
    render :new, status: :unprocessable_entity
  end

  def members
    users = @server.users
                   .where('username ILIKE ?', "#{params[:q]}%")
                   .where.not(id: Current.user.id)
                   .limit(10)

    render json: users.map { |u| { username: u.username, display_name: u.display_name } }
  end

  def show
    @categories = @server.categories.ordered.includes(:channels)
    @unread_channel_ids = unread_channel_ids_for_server(@server)
  end

  def settings
    @tab = 'general'
  end

  def settings_general
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'general',
      panel_partial: 'servers/settings/general_content',
      panel_locals: { server: @server }
    }
  end

  def settings_invite
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'invite',
      panel_partial: 'servers/settings/invite_content',
      panel_locals: { server: @server }
    }
  end

  def settings_danger
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'danger',
      panel_partial: 'servers/settings/danger_content',
      panel_locals: { server: @server, membership: current_membership }
    }
  end

  def settings_channels
    categories = @server.all_categories.order(position: :asc).includes(:channels)
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'channels',
      panel_partial: 'servers/settings/channels_content',
      panel_locals: { server: @server, categories: categories }
    }
  end

  def settings_permissions
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'permissions',
      panel_partial: 'servers/settings/permissions_content',
      panel_locals: { server: @server }
    }
  end

  def settings_members
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'members',
      panel_partial: 'servers/settings/members_content',
      panel_locals: { server: @server, membership: current_membership }
    }
  end

  def remove_member
    user = @server.users.find(params[:user_id])
    Servers::RemoveMemberService.call(server: @server, actor: Current.user, target_user: user)
    redirect_to settings_members_server_path(@server), notice: "Removed #{user.username}."
  rescue Servers::RemoveMemberService::CannotRemoveOwnerError,
         Servers::RemoveMemberService::InsufficientRoleError => e
    redirect_to settings_members_server_path(@server), alert: e.message
  end

  def settings_integrations
    integration = @server.server_integrations.find_or_initialize_by(kind: ServerIntegration::KIND_JAIT)
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'integrations',
      panel_partial: 'servers/settings/integrations_content',
      panel_locals: { server: @server, integration: integration }
    }
  end

  def update_jait_integration
    integration = @server.server_integrations.find_or_initialize_by(kind: ServerIntegration::KIND_JAIT)
    result = ServerIntegrations::SaveJaitService.call(integration: integration, params: params[:integration] || {})
    flash.now[result.flash_key] = result.flash_message
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'integrations',
      panel_partial: 'servers/settings/integrations_content',
      panel_locals: { server: @server, integration: integration }
    }
  end

  def update_permissions
    perms = {
      'members_can_create_channels' => params[:members_can_create_channels] == '1',
      'members_can_create_categories' => params[:members_can_create_categories] == '1'
    }
    Servers::UpdatePermissionsService.call(server: @server, permissions: perms)
    redirect_to settings_permissions_server_path(@server), notice: 'Permissions updated.'
  end

  def edit; end

  def update
    Servers::UpdateSettingsService.call(server: @server, params: server_params)
    redirect_to settings_server_path(@server), notice: 'Server updated.'
  rescue ActiveRecord::RecordInvalid => e
    @server = e.record
    render :settings, status: :unprocessable_entity
  end

  def destroy
    @server.destroy!
    redirect_to servers_path, notice: 'Server deleted.'
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params.require(:server).permit(:name, :description, :icon)
  end
end
