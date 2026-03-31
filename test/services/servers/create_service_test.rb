require 'test_helper'

module Servers
  class CreateServiceTest < ActiveSupport::TestCase
    test 'creates server and owner membership' do
      user = users(:one)
      params = { name: 'My New Server', description: 'A test server' }

      server = Servers::CreateService.call(user: user, params: params)

      assert server.persisted?
      assert_equal 'My New Server', server.name
      assert_equal user, server.owner

      membership = server.membership_for(user)
      assert_not_nil membership
      assert membership.owner?
    end

    test 'rolls back on invalid params' do
      user = users(:one)
      params = { name: '' }

      assert_raises(ActiveRecord::RecordInvalid) do
        Servers::CreateService.call(user: user, params: params)
      end
    end
  end
end
