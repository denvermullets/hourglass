module Channels
  class SettingsController < ApplicationController
    include Authorization

    layout 'app'

    before_action :set_server, :set_channel
    before_action :require_membership!
    before_action :require_moderator!, only: %i[link_project unlink_project update privacy add_member remove_member]
    before_action :load_integration

    def show
      refresh_discovered_teams
      @link = @channel.mtasks_project_link
      @link_state, @linked_project = resolve_link_state(@link)
    end

    def mtasks_projects
      return render(json: []) unless @integration

      list = filter_projects(@integration.client.fetch_projects(params[:team_id]), params[:q])
      render json: list.map { |p| p.slice('id', 'name', 'identifier', 'description') }
    rescue Jait::ApiClient::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

    def link_project
      result = ChannelIntegrations::LinkProjectService.call(
        channel: @channel,
        integration: @integration,
        team_id: params[:team_id],
        project_id: params[:project_id],
        user: Current.user
      )

      if result.ok
        redirect_to server_channel_settings_path(@server, @channel), notice: 'Channel linked.'
      else
        redirect_to server_channel_settings_path(@server, @channel), alert: result.error
      end
    end

    def unlink_project
      ChannelIntegrations::UnlinkProjectService.call(channel: @channel, user: Current.user)
      redirect_to server_channel_settings_path(@server, @channel), notice: 'Channel unlinked.'
    end

    def privacy
      is_private = ActiveModel::Type::Boolean.new.cast(params[:is_private])
      Channels::UpdateService.call(channel: @channel, params: { is_private: is_private })
      notice = @channel.is_private? ? 'Channel is now private.' : 'Channel is now public.'
      redirect_to server_channel_settings_path(@server, @channel), notice: notice
    end

    def add_member
      user = @server.users.find(params[:user_id])
      Channels::AddMemberService.call(channel: @channel, user: user)
      notice = "Added #{user.username} to ##{@channel.name}."
      redirect_to server_channel_settings_path(@server, @channel), notice: notice
    end

    def remove_member
      @channel.channel_memberships.find_by(user_id: params[:user_id])&.destroy!
      redirect_to server_channel_settings_path(@server, @channel), notice: 'Member removed from channel.'
    end

    def update
      pref = params.dig(:channel, :mtasks_system_messages)
      if Channel::MTASKS_SYSTEM_MESSAGE_PREFS.include?(pref)
        @channel.update!(settings: (@channel.settings || {}).merge('mtasks_system_messages' => pref))
        redirect_to server_channel_settings_path(@server, @channel), notice: 'Preference saved.'
      else
        redirect_to server_channel_settings_path(@server, @channel), alert: 'Invalid preference.'
      end
    end

    private

    def set_server
      @server = Server.find(params[:server_id])
    end

    def set_channel
      @channel = @server.channels.find(params[:channel_id])
    end

    def load_integration
      @integration = @server.server_integrations
                            .enabled
                            .for_kind(ServerIntegration::KIND_JAIT)
                            .first
    end

    def refresh_discovered_teams
      return unless @integration&.api_token.present?

      teams = Jait::ApiClient.new(@integration).discover_teams!
      @integration.update!(discovered_teams: teams, last_verified_at: Time.current) if teams.present?
    rescue Jait::ApiClient::Error => e
      Rails.logger.warn("Channels::SettingsController#refresh_discovered_teams failed: #{e.class} #{e.message}")
    end

    def filter_projects(list, query)
      q = query.to_s.downcase
      list = list.select { |p| p['name'].to_s.downcase.include?(q) } if q.present?
      list.first(50)
    end

    def resolve_link_state(link)
      return [:no_integration, nil] unless @integration
      return [:unlinked, nil] unless link

      project = Jait::Fetcher.call(integration: @integration, kind: 'project',
                                   team_id: link.mtasks_team_id, id: link.mtasks_project_id)
      project ? [:linked, project] : [:broken, nil]
    end
  end
end
