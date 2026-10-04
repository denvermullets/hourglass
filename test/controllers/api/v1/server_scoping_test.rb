require 'test_helper'

module Api
  module V1
    # A token bound to one server must not reach any other server, even one the
    # user also belongs to. users(:two) is a member of servers :one and :two.
    class ServerScopingTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:two)
        @server_a = servers(:one)
        @server_b = servers(:two)
        @channel_a = channels(:general)
        @channel_b = @server_b.channels.create!(name: 'b-general', channel_type: :text, position: 0)
        @message_a = messages(:one)
        @message_b = @channel_b.messages.create!(user: @user, body: 'on b', message_type: :regular)
        _token, @raw = ApiToken.generate_for(@user, name: 'b only', server: @server_b)
      end

      def auth_headers(raw = @raw)
        { 'Authorization' => "Bearer #{raw}" }
      end

      def json_headers(raw = @raw)
        auth_headers(raw).merge('Content-Type' => 'application/json')
      end

      # ---- servers ----

      test 'servers#index lists only the bound server' do
        get api_v1_servers_path, headers: auth_headers
        assert_response :success
        assert_equal([@server_b.id], JSON.parse(response.body).map { |s| s['id'] })
      end

      test 'servers#show 404s on another server the user belongs to' do
        get api_v1_server_path(@server_a), headers: auth_headers
        assert_response :not_found

        get api_v1_server_path(@server_b), headers: auth_headers
        assert_response :success
      end

      # ---- channels ----

      test 'channels#index 404s on another server' do
        get api_v1_server_channels_path(@server_a), headers: auth_headers
        assert_response :not_found

        get api_v1_server_channels_path(@server_b), headers: auth_headers
        assert_response :success
        assert_equal([@channel_b.id], JSON.parse(response.body).map { |c| c['id'] })
      end

      test 'channels#show 404s on a channel in another server' do
        get api_v1_channel_path(@channel_a), headers: auth_headers
        assert_response :not_found

        get api_v1_channel_path(@channel_b), headers: auth_headers
        assert_response :success
      end

      # ---- messages ----

      test 'messages#index 404s on a channel in another server' do
        get api_v1_channel_messages_path(@channel_a), headers: auth_headers
        assert_response :not_found

        get api_v1_channel_messages_path(@channel_b), headers: auth_headers
        assert_response :success
      end

      test 'messages#create 404s on a channel in another server' do
        assert_no_difference -> { @channel_a.messages.count } do
          post api_v1_channel_messages_path(@channel_a),
               params: { body: 'leak' }.to_json, headers: json_headers
        end
        assert_response :not_found

        post api_v1_channel_messages_path(@channel_b),
             params: { body: 'fine' }.to_json, headers: json_headers
        assert_response :created
      end

      test 'messages#replies 404s on a message in another server' do
        get api_v1_message_replies_path(@message_a), headers: auth_headers
        assert_response :not_found

        get api_v1_message_replies_path(@message_b), headers: auth_headers
        assert_response :success
      end

      test 'messages#create_reply 404s on a message in another server' do
        assert_no_difference -> { @message_a.replies.count } do
          post api_v1_message_replies_path(@message_a),
               params: { body: 'leak' }.to_json, headers: json_headers
        end
        assert_response :not_found

        post api_v1_message_replies_path(@message_b),
             params: { body: 'fine' }.to_json, headers: json_headers
        assert_response :created
      end

      # ---- membership changes ----

      test 'bound token loses access when the user leaves the bound server' do
        memberships(:two_owner).destroy!

        get api_v1_servers_path, headers: auth_headers
        assert_equal [], JSON.parse(response.body)

        get api_v1_channel_path(@channel_b), headers: auth_headers
        assert_response :not_found
      end

      # ---- unbound tokens ----

      test 'unbound token reaches every server the user belongs to' do
        _token, raw = ApiToken.generate_for(@user, name: 'unbound')

        get api_v1_servers_path, headers: auth_headers(raw)
        ids = JSON.parse(response.body).map { |s| s['id'] }
        assert_includes ids, @server_a.id
        assert_includes ids, @server_b.id

        get api_v1_channel_messages_path(@channel_a), headers: auth_headers(raw)
        assert_response :success
        get api_v1_channel_messages_path(@channel_b), headers: auth_headers(raw)
        assert_response :success
      end

      test 'unbound token cannot reach public channels on servers the user is not in' do
        _token, raw = ApiToken.generate_for(users(:one), name: 'unbound')

        get api_v1_channel_path(@channel_b), headers: auth_headers(raw)
        assert_response :not_found

        get api_v1_channel_messages_path(@channel_b), headers: auth_headers(raw)
        assert_response :not_found

        get api_v1_message_replies_path(@message_b), headers: auth_headers(raw)
        assert_response :not_found
      end
    end
  end
end
