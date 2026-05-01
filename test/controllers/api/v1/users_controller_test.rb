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

      test 'returns the authenticated user on happy path' do
        @user.update!(display_name: 'User One')
        _token, raw = ApiToken.generate_for(@user, name: 'happy')

        get api_v1_me_path, headers: auth_headers(raw)
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal @user.id, body['id']
        assert_equal @user.email_address, body['email']
        assert_equal 'User One', body['display_name']
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
