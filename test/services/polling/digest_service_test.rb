require 'test_helper'

module Polling
  class DigestServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @channel = channels(:general)
    end

    def digest(**overrides)
      DigestService.call(user: @user, channel: @channel, **overrides)
    end

    test 'returns a stable digest for unchanged state' do
      assert_equal digest, digest
    end

    test 'digest changes when a new message is posted in the container' do
      before = digest
      @channel.messages.create!(user: @user, body: 'new', message_type: :regular)
      refute_equal before, digest
    end

    test 'digest changes when an existing message is edited (updated_at bump)' do
      before = digest
      messages(:one).update!(body: 'edited', edited_at: Time.current)
      refute_equal before, digest
    end

    test 'digest changes when a message is soft-deleted' do
      before = digest
      messages(:one).update!(deleted_at: Time.current)
      refute_equal before, digest
    end

    test 'digest changes when read state advances' do
      before = digest
      ChannelMembership.create!(user: @user, channel: @channel, last_read_at: Time.current)
      refute_equal before, digest
    end

    test 'thread context factors parent replies into the digest' do
      parent = messages(:one)
      before = digest(thread: parent)
      parent.replies.create!(user: @user, channel: @channel, body: 'reply', message_type: :regular)
      refute_equal before, digest(thread: parent)
    end

    test 'works with no container context (sidebar/notification only)' do
      assert_kind_of String, DigestService.call(user: @user)
    end
  end
end
