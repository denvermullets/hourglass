require 'test_helper'

class MtasksUserMapTest < ActiveSupport::TestCase
  test 'requires email, mtasks_user_id, hourglass_user' do
    map = MtasksUserMap.new
    assert_not map.valid?
    assert map.errors[:email].any?
    assert map.errors[:mtasks_user_id].any?
    assert map.errors[:hourglass_user].any?
  end

  test 'rejects duplicate email' do
    duplicate = MtasksUserMap.new(
      hourglass_user: users(:one),
      mtasks_user_id: 9999,
      email: mtasks_user_maps(:two).email
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test 'rejects duplicate mtasks_user_id' do
    duplicate = MtasksUserMap.new(
      hourglass_user: users(:one),
      mtasks_user_id: mtasks_user_maps(:two).mtasks_user_id,
      email: 'fresh@example.com'
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:mtasks_user_id].any?
  end

  test 'rejects duplicate hourglass_user' do
    duplicate = MtasksUserMap.new(
      hourglass_user: users(:one),
      mtasks_user_id: 9999,
      email: 'fresh@example.com'
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:hourglass_user_id].any?
  end
end
