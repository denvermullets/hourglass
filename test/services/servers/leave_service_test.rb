require 'test_helper'

module Servers
  class LeaveServiceTest < ActiveSupport::TestCase
    test 'destroys membership' do
      server = servers(:one)
      user = users(:two)

      assert_difference 'Membership.count', -1 do
        Servers::LeaveService.call(user: user, server: server)
      end
    end

    test 'raises OwnerCannotLeaveError for owner' do
      assert_raises(Servers::LeaveService::OwnerCannotLeaveError) do
        Servers::LeaveService.call(user: users(:one), server: servers(:one))
      end
    end

    test 'raises RecordNotFound if not a member' do
      assert_raises(ActiveRecord::RecordNotFound) do
        Servers::LeaveService.call(user: users(:one), server: servers(:two))
      end
    end
  end
end
