require 'test_helper'

module Servers
  class RemoveMemberServiceTest < ActiveSupport::TestCase
    test 'owner removes a member' do
      server = servers(:one)
      target = users(:two)

      assert_difference 'Membership.count', -1 do
        Servers::RemoveMemberService.call(server: server, actor: users(:one), target_user: target)
      end
      assert_nil server.membership_for(target)
    end

    test "does not delete the removed member's messages" do
      server = servers(:one)
      target = users(:two)
      message = channels(:general).messages.create!(user: target, body: 'still here')

      Servers::RemoveMemberService.call(server: server, actor: users(:one), target_user: target)

      assert Message.exists?(message.id), "removed member's message should be preserved"
    end

    test "clears the removed member's channel memberships for that server" do
      server = servers(:one)
      target = users(:two)
      ChannelMembership.create!(channel: channels(:general), user: target)

      assert_difference 'ChannelMembership.count', -1 do
        Servers::RemoveMemberService.call(server: server, actor: users(:one), target_user: target)
      end
    end

    test 'raises CannotRemoveOwnerError when targeting the owner' do
      assert_raises(Servers::RemoveMemberService::CannotRemoveOwnerError) do
        Servers::RemoveMemberService.call(server: servers(:one), actor: users(:one), target_user: users(:one))
      end
    end

    test 'raises InsufficientRoleError when an admin targets another admin' do
      assert_raises(Servers::RemoveMemberService::InsufficientRoleError) do
        Servers::RemoveMemberService.call(server: servers(:one), actor: users(:three), target_user: users(:four))
      end
    end

    test 'raises RecordNotFound when target is not a member' do
      assert_raises(ActiveRecord::RecordNotFound) do
        Servers::RemoveMemberService.call(server: servers(:two), actor: users(:two), target_user: users(:one))
      end
    end
  end
end
