require 'test_helper'

module Servers
  class JoinServiceTest < ActiveSupport::TestCase
    test 'creates membership with valid invite code' do
      server = servers(:two)
      user = users(:one)

      result = Servers::JoinService.call(user: user, invite_code: server.invite_code)

      assert_equal server, result
      membership = server.membership_for(user)
      assert_not_nil membership
      assert membership.member?
    end

    test 'raises RecordNotFound for invalid code' do
      assert_raises(ActiveRecord::RecordNotFound) do
        Servers::JoinService.call(user: users(:one), invite_code: 'badcode1')
      end
    end

    test 'raises AlreadyMemberError if already a member' do
      assert_raises(Servers::JoinService::AlreadyMemberError) do
        Servers::JoinService.call(user: users(:one), invite_code: servers(:one).invite_code)
      end
    end
  end
end
