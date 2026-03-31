require 'test_helper'

class MembershipTest < ActiveSupport::TestCase
  test 'validates uniqueness of user scoped to server' do
    duplicate = Membership.new(user: users(:one), server: servers(:one), role: :member)
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test 'sets joined_at automatically' do
    membership = Membership.create!(user: users(:one), server: servers(:two), role: :member)
    assert_not_nil membership.joined_at
  end

  test 'validates nickname max length' do
    membership = memberships(:one_owner)
    membership.nickname = 'a' * 33
    assert_not membership.valid?
    assert membership.errors[:nickname].any?
  end

  test 'enum owner?' do
    assert memberships(:one_owner).owner?
  end

  test 'enum member?' do
    assert memberships(:two_member_of_one).member?
  end

  test 'at_least? owner is at least admin' do
    assert memberships(:one_owner).at_least?(:admin)
  end

  test 'at_least? owner is at least owner' do
    assert memberships(:one_owner).at_least?(:owner)
  end

  test 'at_least? member is not at least moderator' do
    assert_not memberships(:two_member_of_one).at_least?(:moderator)
  end

  test 'can_manage_channels? for moderator and above' do
    assert memberships(:one_owner).can_manage_channels?
    assert_not memberships(:two_member_of_one).can_manage_channels?
  end

  test 'can_manage_members? for admin and above' do
    assert memberships(:one_owner).can_manage_members?
    assert_not memberships(:two_member_of_one).can_manage_members?
  end

  test 'can_manage_server? for admin and above' do
    assert memberships(:one_owner).can_manage_server?
    assert_not memberships(:two_member_of_one).can_manage_server?
  end

  test 'can_delete_server? only for owner' do
    assert memberships(:one_owner).can_delete_server?
    assert_not memberships(:two_member_of_one).can_delete_server?
  end
end
