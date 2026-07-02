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

    # Phase 3 sensitivity: with broadcasts gone, morph must fire on activity in ANOTHER
    # visible channel (booleans alone missed a second channel going unread).
    test 'digest changes when a different visible channel gets activity' do
      other = @channel.server.channels.create!(name: 'random', channel_type: :text, is_private: false)
      before = digest
      other.update_column(:last_message_at, Time.current)
      refute_equal before, digest
    end

    # Sidebar structure (create/archive/rename) is now derived via morph.
    test 'digest changes when a channel is created (sidebar structure)' do
      before = digest
      @channel.server.channels.create!(name: 'new-chan', channel_type: :text, is_private: false)
      refute_equal before, digest
    end

    test 'digest changes when the server online count changes' do
      before = digest
      users(:two).update_column(:last_seen_at, Time.current)
      refute_equal before, digest
    end

    test 'digest changes when the channel jait link changes' do
      before = digest
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one),
        channel: @channel,
        mtasks_team_id: 21,
        mtasks_project_id: 7,
        created_by_user: @user
      )
      refute_equal before, digest
    end
  end
end
