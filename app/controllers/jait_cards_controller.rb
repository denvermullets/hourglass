class JaitCardsController < ApplicationController
  include Authorization

  before_action :set_server
  before_action :require_membership!
  before_action :set_integration

  def show
    kind = params[:kind].to_s
    return render_unavailable unless %w[issue project roadmap].include?(kind)

    team_id = params[:team_id].to_i
    return render_unavailable unless @integration.team_for(team_id)

    data = Jait::Fetcher.call(integration: @integration, kind: kind, team_id: team_id, id: params[:id])
    return render_unavailable if data.nil?

    render partial: "jait_cards/#{kind}", locals: {
      data: data, integration: @integration, team_id: team_id, frame_id: frame_id
    }
  end

  def show_by_identifier
    team_id = params[:team_id].to_i
    return render_unavailable unless @integration.team_for(team_id)

    data = Jait::Fetcher.call(integration: @integration, kind: 'issue', team_id: team_id,
                              identifier: params[:identifier])
    return render_unavailable if data.nil?

    render partial: 'jait_cards/issue', locals: {
      data: data, integration: @integration, team_id: team_id, frame_id: frame_id
    }
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_integration
    return if performed?

    @integration = @server.jait_integration
    render_unavailable if @integration.nil? || !@integration.configured?
  end

  def render_unavailable
    render partial: 'jait_cards/unavailable', locals: { frame_id: frame_id }
  end

  def frame_id
    return "jait-issue-ident-#{params[:identifier]}" if params[:identifier].present?

    parts = ["jait-#{params[:kind]}", frame_id_team_id, params[:id].presence].compact
    parts.join('-')
  end

  def frame_id_team_id
    params[:team_id].presence || @integration&.team_ids&.first || @server&.id
  end
end
