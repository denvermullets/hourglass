require 'test_helper'

module Channels
  class UpdateServiceTest < ActiveSupport::TestCase
    test 'switching a channel to private snapshots a membership for every server member' do
      channel = channels(:general)
      member_count = channel.server.users.count

      assert_difference 'ChannelMembership.count', member_count do
        Channels::UpdateService.call(channel: channel, params: { is_private: true })
      end

      assert channel.reload.is_private?
      channel.server.users.each do |user|
        assert ChannelMembership.exists?(channel: channel, user: user)
      end
    end

    test 'snapshot is idempotent and does not duplicate existing memberships' do
      channel = channels(:general)
      ChannelMembership.create!(channel: channel, user: users(:one))
      member_count = channel.server.users.count

      # One row already exists, so only the remaining members get new rows.
      assert_difference 'ChannelMembership.count', member_count - 1 do
        Channels::UpdateService.call(channel: channel, params: { is_private: true })
      end
    end

    test 'a non-privacy update does not create memberships' do
      channel = channels(:general)

      assert_no_difference 'ChannelMembership.count' do
        Channels::UpdateService.call(channel: channel, params: { topic: 'new topic' })
      end
    end
  end
end
