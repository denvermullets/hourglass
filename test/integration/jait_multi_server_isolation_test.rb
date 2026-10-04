require 'test_helper'

# JAIT-257: one person, two Hourglass servers, each connected to different
# JAIT teams. Nothing done through server X's integration may reach server Y,
# its channels or its teams, and vice versa.
#
#   JAIT team T1, T2  <->  Hourglass server X (servers(:one))
#   JAIT team T3      <->  Hourglass server Y (servers(:two))
#   JAIT team T4         control team, connected to neither
#
# users(:two) is a member of both servers. JAIT is faked at the Net::HTTP
# layer so every test can check which host and token were actually used.
class JaitMultiServerIsolationTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  include ActiveJob::TestHelper

  T1 = 41
  T2 = 42
  T3 = 43
  T4 = 44
  X_HOST = 'x.jait.test'.freeze
  Y_HOST = 'y.jait.test'.freeze

  # Records every request and answers from a [host, method, path] => body map.
  # Unrouted requests get a 404, which Jait::Fetcher turns into nil.
  class FakeJait
    Call = Struct.new(:host, :verb, :path, :auth)
    Response = Struct.new(:code, :body)
    Session = Struct.new(:fake, :host) do
      def request(req) = fake.respond(host, req)
    end

    attr_reader :calls, :routes

    def initialize
      @calls = []
      @routes = {}
    end

    def respond(host, req)
      calls << Call.new(host, req.method, req.path, req['Authorization'])
      body = routes[[host, req.method, req.path]]
      body.nil? ? Response.new('404', '{}') : Response.new('200', body.to_json)
    end

    def calls_to(host) = calls.select { |c| c.host == host }
  end

  setup do
    @user = users(:two)
    @server_x = servers(:one)
    @server_y = servers(:two)

    @integration_x = server_integrations(:jait_one)
    @integration_x.update!(
      base_url: "https://#{X_HOST}", api_token: 'x-token', webhook_secret: 'x-secret',
      discovered_teams: [team(T1, 'ONE'), team(T2, 'TWO')]
    )
    @integration_y = @server_y.server_integrations.create!(
      kind: ServerIntegration::KIND_JAIT, enabled: true,
      base_url: "https://#{Y_HOST}", api_token: 'y-token', webhook_secret: 'y-secret',
      discovered_teams: [team(T3, 'THREE')]
    )

    @channel_x = channels(:general)
    @channel_y = @server_y.channels.create!(name: 'y-general', channel_type: :text, position: 0)

    install_fake_jait
  end

  teardown do
    restore_net_http
  end

  def team(id, identifier)
    { 'id' => id, 'identifier' => identifier, 'name' => identifier.capitalize }
  end

  def install_fake_jait
    @jait = FakeJait.new
    @jait.routes[[X_HOST, 'GET', '/api/v1/teams']] = { teams: [team(T1, 'ONE'), team(T2, 'TWO')] }
    @jait.routes[[Y_HOST, 'GET', '/api/v1/teams']] = { teams: [team(T3, 'THREE')] }

    fake = @jait
    Net::HTTP.singleton_class.alias_method(:_jait_isolation_orig_start, :start)
    Net::HTTP.define_singleton_method(:start) { |host, *_a, **_k, &blk| blk.call(FakeJait::Session.new(fake, host)) }
  end

  def restore_net_http
    sclass = Net::HTTP.singleton_class
    sclass.alias_method(:start, :_jait_isolation_orig_start)
    sclass.send(:remove_method, :_jait_isolation_orig_start)
  end

  def link_project(integration:, channel:, team_id:, project_id:)
    MtasksLink.create!(
      link_type: MtasksLink::PROJECT_CHANNEL, server_integration: integration, channel: channel,
      mtasks_team_id: team_id, mtasks_project_id: project_id, created_by_user: @user
    )
  end

  # ---- API tokens ----

  def bearer(server)
    _token, raw = ApiToken.generate_for(@user, name: "bound to #{server.name}", server: server)
    { 'Authorization' => "Bearer #{raw}" }
  end

  test "X-bound token: /me returns X and X's integration, never Y's" do
    get api_v1_me_path, headers: bearer(@server_x)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @server_x.id, body.dig('server', 'id')
    assert_equal @integration_x.id, body.dig('integration', 'id')
    assert_equal 'x-secret', body.dig('integration', 'webhook_secret')

    get api_v1_me_path, headers: bearer(@server_y)
    body = JSON.parse(response.body)
    assert_equal @server_y.id, body.dig('server', 'id')
    assert_equal @integration_y.id, body.dig('integration', 'id')
    assert_equal 'y-secret', body.dig('integration', 'webhook_secret')
  end

  test "X-bound token gets 404 on Y's server, channels and messages" do
    headers = bearer(@server_x)

    get api_v1_server_path(@server_y), headers: headers
    assert_response :not_found
    get api_v1_server_channels_path(@server_y), headers: headers
    assert_response :not_found
    get api_v1_channel_path(@channel_y), headers: headers
    assert_response :not_found
    get api_v1_channel_messages_path(@channel_y), headers: headers
    assert_response :not_found

    get api_v1_channel_path(@channel_x), headers: headers
    assert_response :success
  end

  # ---- inbound webhooks ----

  def post_webhook(integration, event:, data:, secret: integration.webhook_secret)
    delivery_id = SecureRandom.uuid
    body = { version: 1, event: event, delivery_id: delivery_id, data: data }.to_json
    headers = {
      'Content-Type' => 'application/json',
      'X-Mtasks-Event' => event,
      'X-Mtasks-Delivery' => delivery_id,
      'X-Mtasks-Timestamp' => Time.current.to_i.to_s,
      'X-Mtasks-Signature-256' => "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, body)}"
    }
    perform_enqueued_jobs { post webhooks_mtasks_path(integration), params: body, headers: headers }
  end

  test "each integration's webhook verifies only with its own secret" do
    data = { link_type: 'project_channel', mtasks_project_id: 1, hourglass_channel_id: 0 }

    assert_no_difference 'WebhookDelivery.count' do
      post_webhook(@integration_y, event: 'link.created', data: data, secret: 'x-secret')
      assert_response :unauthorized
      post_webhook(@integration_x, event: 'link.created', data: data, secret: 'y-secret')
      assert_response :unauthorized
    end

    post_webhook(@integration_x, event: 'link.created', data: data)
    assert_response :ok
    assert_equal @integration_x, WebhookDelivery.last.server_integration

    post_webhook(@integration_y, event: 'link.created', data: data)
    assert_response :ok
    assert_equal @integration_y, WebhookDelivery.last.server_integration
  end

  test 'link.created signed by X that names a Y channel creates no link' do
    @jait.routes[[Y_HOST, 'GET', "/api/v1/teams/#{T3}/projects/9"]] = { id: 9 }

    # A real Y channel, team and project: only the signer is wrong.
    assert_no_difference 'MtasksLink.count' do
      post_webhook(@integration_x, event: 'link.created', data: {
                     link_type: 'project_channel', mtasks_project_id: 9,
                     mtasks_team_id: T3, hourglass_channel_id: @channel_y.id
                   })
    end
    assert_response :ok
    assert WebhookDelivery.last.processed?
  end

  test 'link.created signed by X that names T3 or T4 creates no link' do
    # Project 9 is visible to X under T1, so silently re-homing the link onto
    # one of X's own teams would also succeed. It must be rejected instead.
    @jait.routes[[X_HOST, 'GET', "/api/v1/teams/#{T1}/projects/9"]] = { id: 9 }

    [T3, T4].each do |team_id|
      assert_no_difference 'MtasksLink.count' do
        post_webhook(@integration_x, event: 'link.created', data: {
                       link_type: 'project_channel', mtasks_project_id: 9,
                       mtasks_team_id: team_id, hourglass_channel_id: @channel_x.id
                     })
      end
    end
    # The unknown team triggers one team refresh, against X only.
    assert @jait.calls_to(Y_HOST).empty?
  end

  test "issue.created signed by X never posts into Y's linked channel" do
    link_project(integration: @integration_y, channel: @channel_y, team_id: T3, project_id: 9)
    issue = { issue_id: 900, identifier: 'THREE-900', project_id: 9, title: 'leak?' }

    assert_no_difference -> { @channel_y.messages.count } do
      post_webhook(@integration_x, event: 'issue.created', data: issue.merge(team_id: T3))
      post_webhook(@integration_x, event: 'issue.created', data: issue)
    end

    # Control: the same event signed by Y lands in Y's channel.
    assert_difference -> { @channel_y.messages.count }, 1 do
      post_webhook(@integration_y, event: 'issue.created', data: issue.merge(team_id: T3))
    end
  end

  # ---- LinkProjectService ----

  def link_service(integration:, channel:, team_id:, project_id: 9)
    ChannelIntegrations::LinkProjectService.call(
      channel: channel, integration: integration, team_id: team_id, project_id: project_id, user: @user
    )
  end

  test "LinkProjectService on X refuses T3, T4 and Y's channel without calling JAIT" do
    assert_no_difference 'MtasksLink.count' do
      [T3, T4].each do |team_id|
        result = link_service(integration: @integration_x, channel: @channel_x, team_id: team_id)
        assert_not result.ok
        assert_match(/team not in this integration/, result.error)
      end

      result = link_service(integration: @integration_x, channel: @channel_y, team_id: T1)
      assert_not result.ok
      assert_match(/channel not on this integration's server/, result.error)
    end
    assert_empty @jait.calls
  end

  test 'LinkProjectService on Y links T3 using only Y host and token' do
    @jait.routes[[Y_HOST, 'GET', "/api/v1/teams/#{T3}/projects/9"]] = { id: 9, name: 'Y roadmap' }

    result = link_service(integration: @integration_y, channel: @channel_y, team_id: T3)
    assert result.ok, result.error
    assert_equal @integration_y, result.link.server_integration
    assert_equal T3, result.link.mtasks_team_id

    assert_empty @jait.calls_to(X_HOST)
    assert(@jait.calls.all? { |c| c.auth == 'Bearer y-token' })
  end

  # ---- outbound ----

  test "outbound message.created for a Y link only calls Y's base_url with Y's token" do
    link_y = link_project(integration: @integration_y, channel: @channel_y, team_id: T3, project_id: 9)
    link_x = link_project(integration: @integration_x, channel: @channel_x, team_id: T1, project_id: 7)
    message_y = @channel_y.messages.create!(user: @user, body: 'from y')
    message_x = @channel_x.messages.create!(user: @user, body: 'from x')
    @jait.routes[[Y_HOST, 'POST', "/api/v1/teams/#{T3}/projects/9/comments"]] = { id: 1 }
    @jait.routes[[X_HOST, 'POST', "/api/v1/teams/#{T1}/projects/7/comments"]] = { id: 2 }

    MtasksOutboundEmitterJob.perform_now(event_type: 'message.created', message_id: message_y.id, link_id: link_y.id)
    assert_equal([[Y_HOST, 'Bearer y-token']], @jait.calls.map { |c| [c.host, c.auth] })

    MtasksOutboundEmitterJob.perform_now(event_type: 'message.created', message_id: message_x.id, link_id: link_x.id)
    assert_equal([X_HOST, 'Bearer x-token'], @jait.calls.last.then { |c| [c.host, c.auth] })
  end
end
