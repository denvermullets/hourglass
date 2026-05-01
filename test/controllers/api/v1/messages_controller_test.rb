require 'test_helper'

module Api
  module V1
    class MessagesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        _token, @raw = ApiToken.generate_for(@user, name: 'messages test')
        @channel = channels(:general)
      end

      def auth_headers(extra = {})
        { 'Authorization' => "Bearer #{@raw}" }.merge(extra)
      end

      def json_headers(extra = {})
        auth_headers({ 'Content-Type' => 'application/json' }.merge(extra))
      end

      # ---- index ----

      test 'index requires auth' do
        get api_v1_channel_messages_path(@channel)
        assert_response :unauthorized
      end

      test 'index returns root messages ascending, excluding deleted' do
        get api_v1_channel_messages_path(@channel), headers: auth_headers
        assert_response :success

        body = JSON.parse(response.body)
        ids = body.map { |m| m['id'] }
        assert_includes ids, messages(:one).id
        assert_includes ids, messages(:two).id
        assert_not_includes ids, messages(:deleted).id
        assert_equal ids, ids.sort
      end

      test 'index pagination: default limit 50, max 100, since filter' do
        # Seed >100 extra messages so the over-max clamp is testable
        110.times { |i| @channel.messages.create!(user: @user, body: "msg #{i}", message_type: :regular) }

        # default
        get api_v1_channel_messages_path(@channel), headers: auth_headers
        assert_equal 50, JSON.parse(response.body).size

        # explicit limit
        get api_v1_channel_messages_path(@channel, limit: 10), headers: auth_headers
        assert_equal 10, JSON.parse(response.body).size

        # over-max clamped
        get api_v1_channel_messages_path(@channel, limit: 999), headers: auth_headers
        assert_equal 100, JSON.parse(response.body).size

        # since
        first_page = JSON.parse(response.body)
        cursor = first_page[9]['id']
        get api_v1_channel_messages_path(@channel, since: cursor, limit: 5), headers: auth_headers
        next_page = JSON.parse(response.body)
        assert(next_page.all? { |m| m['id'] > cursor })
        assert_equal 5, next_page.size
      end

      test 'index returns 404 for a private channel the user is not a member of' do
        private_channel = @channel.server.channels.create!(
          name: 'secret', is_private: true, channel_type: :text, position: 99
        )
        get api_v1_channel_messages_path(private_channel), headers: auth_headers
        assert_response :not_found
      end

      # ---- create ----

      test 'create posts a message and returns 201' do
        assert_difference 'Message.count', 1 do
          post api_v1_channel_messages_path(@channel),
               params: { body: 'hi from api' }.to_json,
               headers: json_headers
        end
        assert_response :created

        body = JSON.parse(response.body)
        assert_equal 'hi from api', body['body']
        assert_equal @user.id, body['user_id']
        assert_equal @channel.id, body['channel_id']
        assert_nil body['parent_message_id']
      end

      test 'create with empty body returns 422' do
        assert_no_difference 'Message.count' do
          post api_v1_channel_messages_path(@channel),
               params: { body: '' }.to_json,
               headers: json_headers
        end
        assert_response :unprocessable_entity
        body = JSON.parse(response.body)
        assert_equal 'Unprocessable Entity', body['error']
        assert_kind_of Array, body['errors']
      end

      test 'create returns 404 in a private channel the user is not a member of' do
        private_channel = @channel.server.channels.create!(
          name: 'secret', is_private: true, channel_type: :text, position: 99
        )
        post api_v1_channel_messages_path(private_channel),
             params: { body: 'hello' }.to_json,
             headers: json_headers
        assert_response :not_found
      end

      # ---- idempotency ----

      class IdempotencyTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:one)
          _token, @raw = ApiToken.generate_for(@user, name: 'idempotency test')
          @channel = channels(:general)

          @original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
        end

        teardown do
          Rails.cache = @original_cache
        end

        def headers(extra = {})
          { 'Authorization' => "Bearer #{@raw}", 'Content-Type' => 'application/json' }.merge(extra)
        end

        test 'replays the same response and does not create a duplicate' do
          key = SecureRandom.uuid

          assert_difference 'Message.count', 1 do
            post api_v1_channel_messages_path(@channel),
                 params: { body: 'first' }.to_json,
                 headers: headers('Idempotency-Key' => key)
          end
          first_body = response.body
          first_status = response.status

          assert_no_difference 'Message.count' do
            post api_v1_channel_messages_path(@channel),
                 params: { body: 'first' }.to_json,
                 headers: headers('Idempotency-Key' => key)
          end
          assert_equal first_status, response.status
          assert_equal JSON.parse(first_body), JSON.parse(response.body)
        end

        test 'replays validation failures (4xx) too' do
          key = SecureRandom.uuid

          assert_no_difference 'Message.count' do
            post api_v1_channel_messages_path(@channel),
                 params: { body: '' }.to_json,
                 headers: headers('Idempotency-Key' => key)
          end
          first_body = response.body
          assert_response :unprocessable_entity

          assert_no_difference 'Message.count' do
            post api_v1_channel_messages_path(@channel),
                 params: { body: '' }.to_json,
                 headers: headers('Idempotency-Key' => key)
          end
          assert_response :unprocessable_entity
          assert_equal JSON.parse(first_body), JSON.parse(response.body)
        end

        test 'different keys do not collide' do
          assert_difference 'Message.count', 2 do
            post api_v1_channel_messages_path(@channel),
                 params: { body: 'a' }.to_json,
                 headers: headers('Idempotency-Key' => SecureRandom.uuid)
            post api_v1_channel_messages_path(@channel),
                 params: { body: 'b' }.to_json,
                 headers: headers('Idempotency-Key' => SecureRandom.uuid)
          end
        end
      end

      # ---- replies ----

      test 'replies returns only replies of the parent, ascending' do
        parent = messages(:one)
        @channel.messages.create!(user: @user, body: 'r1', parent_message: parent, message_type: :regular)
        @channel.messages.create!(user: @user, body: 'r2', parent_message: parent, message_type: :regular)

        get api_v1_message_replies_path(parent), headers: auth_headers
        assert_response :success

        body = JSON.parse(response.body)
        assert_equal 2, body.size
        assert(body.all? { |m| m['parent_message_id'] == parent.id })
        ids = body.map { |m| m['id'] }
        assert_equal ids, ids.sort
      end

      test 'create_reply creates a reply and bumps parent replies_count' do
        parent = messages(:one)
        before_count = parent.replies_count.to_i

        post api_v1_message_replies_path(parent),
             params: { body: 'thread reply' }.to_json,
             headers: json_headers
        assert_response :created

        body = JSON.parse(response.body)
        assert_equal parent.id, body['parent_message_id']
        assert_equal 'thread reply', body['body']
        assert_equal before_count + 1, parent.reload.replies_count.to_i
      end

      test 'create_reply 404 when parent is in a private channel the user is not a member of' do
        private_channel = @channel.server.channels.create!(
          name: 'secret-thread', is_private: true, channel_type: :text, position: 100
        )
        # Create parent message owned by another user in the private channel
        parent = private_channel.messages.create!(user: users(:two), body: 'private parent', message_type: :regular)

        post api_v1_message_replies_path(parent),
             params: { body: 'sneak' }.to_json,
             headers: json_headers
        assert_response :not_found
      end
    end
  end
end
