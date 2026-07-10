class JaitWebhookTestsController < ApplicationController
  include Authorization

  before_action :set_server
  before_action :require_membership!

  def create
    integration = @server.server_integrations.find_by!(kind: ServerIntegration::KIND_JAIT)
    integration.ensure_webhook_secret!

    payload_data = parse_payload
    return render_integrations_panel(integration) if payload_data.nil?

    result = Webhooks::MtasksTestDispatcher.call(
      integration: integration,
      event_type: params[:event_type].to_s,
      payload_data: payload_data,
      host: request.host_with_port
    )
    flash_for(result)
    render_integrations_panel(integration)
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def parse_payload
    JSON.parse(params[:payload_data].to_s)
  rescue JSON::ParserError
    flash.now[:alert] = 'payload must be valid JSON'
    nil
  end

  def flash_for(result)
    if result.ok
      flash.now[:notice] = "Delivery received (id ##{result.delivery&.id})."
    elsif result.error.present?
      flash.now[:alert] = "Test webhook failed: #{result.error}"
    else
      flash.now[:alert] = "Test webhook failed (HTTP #{result.status})."
    end
  end

  def render_integrations_panel(integration)
    render partial: 'servers/settings/tabs_and_panel', locals: {
      server: @server, tab: 'integrations',
      panel_partial: 'servers/settings/integrations_content',
      panel_locals: { server: @server, integration: integration }
    }
  end
end
