class ServersController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server,
                only: %i[show edit update destroy settings settings_general settings_invite settings_danger members]
  before_action :require_membership!, only: %i[show members]
  before_action :require_admin!,
                only: %i[settings settings_general settings_invite settings_danger edit update]
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
