require 'test_helper'

module Api
  module V1
    class UsersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
      end

      def auth_headers(raw)
        { 'Authorization' => "Bearer #{raw}" }
      end

      test 'returns 401 with no Authorization header' do
        get api_v1_me_path
        assert_response :unauthorized
        body = JSON.parse(response.body)
        assert_equal 'Unauthorized', body['error']
        assert_includes body['message'], 'API token'
      end

      test 'returns 401 for an unknown token' do
        get api_v1_me_path, headers: auth_headers('not-a-real-token')
        assert_response :unauthorized
      end

      test 'returns 401 for a revoked token' do
        token, raw = ApiToken.generate_for(@user, name: 'revoked')
        token.revoke!

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :unauthorized
      end

      test 'returns 403 when token lacks read scope' do
        _token, raw = ApiToken.generate_for(@user, name: 'write only', scopes: %w[write])

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :forbidden
        body = JSON.parse(response.body)
        assert_equal 'Forbidden', body['error']
      end

      test 'returns the authenticated user and the token server on happy path' do
        @user.update!(display_name: 'User One')
        server = servers(:one)
        _token, raw = ApiToken.generate_for(@user, name: 'happy', server: server)

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal @user.id, body['id']
        assert_equal @user.email_address, body['email']
        assert_equal 'User One', body['display_name']
        assert_equal server.id, body.dig('server', 'id')
        assert_equal server.name, body.dig('server', 'name')
        assert_equal server_integrations(:jait_one).id, body.dig('integration', 'id')
        assert_equal server_integrations(:jait_one).webhook_secret, body.dig('integration', 'webhook_secret')
      end

      test 'multi-server user: token bound to the second server returns that server' do
        multi = users(:two) # member of servers one and two
        server_b = servers(:two)
        integration_b = server_b.server_integrations.create!(
          kind: 'jait', enabled: true, api_token: 'tok-b',
          base_url: 'https://justanotherissuetracker.com', webhook_secret: 'secret-b'
        )
        _token, raw = ApiToken.generate_for(multi, name: 'b only', server: server_b)

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal server_b.id, body.dig('server', 'id')
        assert_equal integration_b.id, body.dig('integration', 'id')
        assert_equal 'secret-b', body.dig('integration', 'webhook_secret')
      end

      test 'unbound token returns server and integration nil' do
        _token, raw = ApiToken.generate_for(@user, name: 'unbound')

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal @user.id, body['id']
        assert_nil body['server']
        assert_nil body['integration']
      end

      test 'bound token returns server nil once the user leaves that server' do
        token, raw = ApiToken.generate_for(@user, name: 'left', server: servers(:one))
        memberships(:one_owner).destroy!

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_nil body['server']
        assert_nil body['integration']
        assert_equal servers(:one).id, token.reload.server_id
      end

      test 'integration is nil when the server has no enabled jait integration' do
        server_integrations(:jait_one).update!(enabled: false)
        _token, raw = ApiToken.generate_for(@user, name: 'no-int', server: servers(:one))

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal servers(:one).id, body.dig('server', 'id')
        assert_nil body['integration']
      end

      test 'updates last_used_at on successful auth' do
        token, raw = ApiToken.generate_for(@user, name: 'usage')
        assert_nil token.last_used_at

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        token.reload
        assert_not_nil token.last_used_at
        assert_in_delta Time.current, token.last_used_at, 5
      end
    end
  end
end
