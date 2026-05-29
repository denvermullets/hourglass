require 'test_helper'

module Settings
  class ApiTokensControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as(@user)
    end

    test 'requires authentication' do
      sign_out
      get settings_api_tokens_path
      assert_response :redirect
    end

    test 'index lists current user active tokens' do
      get settings_api_tokens_path
      assert_response :success
      assert_match api_tokens(:active_one).name, response.body
      assert_no_match api_tokens(:revoked_one).name, response.body
      assert_no_match api_tokens(:active_two).name, response.body
    end

    test 'create persists token and shows raw value once' do
      assert_difference 'ApiToken.count', 1 do
        post settings_api_tokens_path,
             params: { api_token: { name: 'integration test' } },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end
      assert_response :success

      new_token = @user.api_tokens.order(created_at: :desc).first
      assert_equal 'integration test', new_token.name
      assert_match new_token.name, response.body

      get settings_api_tokens_path
      raw_blocks = response.body.scan(%r{<code[^>]*>([^<]+)</code>}).flatten.join(' ')
      assert_no_match(/[A-Za-z0-9_-]{32,}/, raw_blocks)
    end

    test 'create with blank name renders error' do
      assert_no_difference 'ApiToken.count' do
        post settings_api_tokens_path,
             params: { api_token: { name: '' } }
      end
      assert_response :unprocessable_entity
    end

    test 'destroy revokes the token' do
      token = api_tokens(:active_one)
      delete settings_api_token_path(token),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      assert_response :success
      assert token.reload.revoked?
    end

    test 'cannot revoke another user token' do
      other = api_tokens(:active_two)
      delete settings_api_token_path(other)
      assert_response :not_found
      assert_not other.reload.revoked?
    end
  end
end
