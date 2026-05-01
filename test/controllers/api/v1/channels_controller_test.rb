require 'test_helper'

module Api
  module V1
    class ChannelsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        _token, @raw = ApiToken.generate_for(@user, name: 'channels test')
        @server = servers(:one)
        @public_channel = channels(:general)
      end

      def auth_headers
        { 'Authorization' => "Bearer #{@raw}" }
      end

      test 'index requires auth' do
        get api_v1_server_channels_path(@server)
        assert_response :unauthorized
      end

      test 'index returns channels for a member server' do
        get api_v1_server_channels_path(@server), headers: auth_headers
        assert_response :success

        ids = JSON.parse(response.body).map { |c| c['id'] }
        assert_includes ids, @public_channel.id
      end

      test 'index returns 404 for a server the user is not a member of' do
        non_member_server = servers(:two)
        get api_v1_server_channels_path(non_member_server), headers: auth_headers
        assert_response :not_found
      end

      test 'index excludes private channels the user is not a member of' do
        private_channel = @server.channels.create!(
          name: 'secret', is_private: true, channel_type: :text, position: 1
        )

        get api_v1_server_channels_path(@server), headers: auth_headers
        ids = JSON.parse(response.body).map { |c| c['id'] }
        assert_not_includes ids, private_channel.id
      end

      test 'index includes private channels the user IS a member of' do
        private_channel = @server.channels.create!(
          name: 'secret', is_private: true, channel_type: :text, position: 1
        )
        ChannelMembership.create!(user: @user, channel: private_channel)

        get api_v1_server_channels_path(@server), headers: auth_headers
        ids = JSON.parse(response.body).map { |c| c['id'] }
        assert_includes ids, private_channel.id
      end

      test 'show returns the channel for a public channel' do
        get api_v1_channel_path(@public_channel), headers: auth_headers
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal @public_channel.id, body['id']
        assert_equal @public_channel.name, body['name']
        assert_equal false, body['is_private']
      end

      test 'show returns 404 for a private channel the user is not a member of' do
        private_channel = @server.channels.create!(
          name: 'secret', is_private: true, channel_type: :text, position: 1
        )

        get api_v1_channel_path(private_channel), headers: auth_headers
        assert_response :not_found
      end

      test 'show returns 404 for unknown id' do
        get api_v1_channel_path(id: 999_999), headers: auth_headers
        assert_response :not_found
      end
    end
  end
end
