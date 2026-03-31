require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  test 'validates name presence' do
    server = Server.new(owner: users(:one))
    assert_not server.valid?
    assert server.errors[:name].any?
  end

  test 'validates name max length' do
    server = servers(:one)
    server.name = 'a' * 101
    assert_not server.valid?
    assert server.errors[:name].any?
  end

  test 'validates description max length' do
    server = servers(:one)
    server.description = 'a' * 1001
    assert_not server.valid?
    assert server.errors[:description].any?
  end

  test 'auto-generates invite_code on create' do
    server = Server.create!(name: 'New Server', owner: users(:one))
    assert_not_nil server.invite_code
    assert_equal 8, server.invite_code.length
  end

  test 'invite_code must be unique' do
    server = Server.new(name: 'Dupe', owner: users(:one), invite_code: servers(:one).invite_code)
    assert_not server.valid?
    assert server.errors[:invite_code].any?
  end

  test 'regenerate_invite_code! changes the code' do
    server = servers(:one)
    old_code = server.invite_code
    server.regenerate_invite_code!
    assert_not_equal old_code, server.invite_code
  end

  test 'membership_for returns membership' do
    server = servers(:one)
    membership = server.membership_for(users(:one))
    assert_not_nil membership
    assert_equal 'owner', membership.role
  end

  test 'membership_for returns nil for non-member' do
    server = servers(:two)
    assert_nil server.membership_for(users(:one))
  end

  test 'has_many memberships' do
    assert servers(:one).memberships.count >= 1
  end

  test 'has_many users through memberships' do
    assert servers(:one).users.include?(users(:one))
  end

  test 'belongs_to owner' do
    assert_equal users(:one), servers(:one).owner
  end
end
