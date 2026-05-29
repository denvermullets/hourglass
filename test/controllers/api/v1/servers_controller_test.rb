require 'test_helper'

module Api
  module V1
    class ServersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        _token, @raw = ApiToken.generate_for(@user, name: 'servers test')
      end

      def auth_headers(raw = @raw)
        { 'Authorization' => "Bearer #{raw}" }
      end

      test 'index requires authentication' do
        get api_v1_servers_path
        assert_response :unauthorized
      end

      test 'index returns only servers the user is a member of' do
        get api_v1_servers_path, headers: auth_headers
        assert_response :success

        body = JSON.parse(response.body)
        ids = body.map { |s| s['id'] }
        assert_includes ids, servers(:one).id
        assert_not_includes ids, servers(:two).id
      end

      test 'index payload shape' do
        get api_v1_servers_path, headers: auth_headers
        body = JSON.parse(response.body)
        server = body.find { |s| s['id'] == servers(:one).id }

        assert_equal servers(:one).name, server['name']
        assert_equal servers(:one).description, server['description']
      end

      test 'show returns the server for a member' do
        get api_v1_server_path(servers(:one)), headers: auth_headers
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal servers(:one).id, body['id']
        assert_equal servers(:one).name, body['name']
      end

      test 'show returns 404 for a server the user is not a member of' do
        get api_v1_server_path(servers(:two)), headers: auth_headers
        assert_response :not_found
        body = JSON.parse(response.body)
        assert_equal 'Not Found', body['error']
      end

      test 'show returns 404 for unknown id' do
        get api_v1_server_path(id: 999_999), headers: auth_headers
        assert_response :not_found
      end
    end
  end
end
