require 'test_helper'

class JaitWebhookTestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @server = servers(:one)
  end

  test 'renders the integrations panel frame (not a 404 error page)' do
    # Outbound loopback will be refused and rescued; we only assert the response
    # is the settings_panel turbo frame so Turbo can swap it in.
    post test_jait_webhook_server_path(@server),
         params: { event_type: 'link.created', payload_data: '{"link_type":"project_channel"}' }

    assert_response :success
    assert_includes response.body, 'id="settings_panel"'
  end
end
