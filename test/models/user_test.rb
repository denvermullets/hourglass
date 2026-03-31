require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'downcases and strips email_address' do
    user = User.new(email_address: ' DOWNCASED@EXAMPLE.COM ')
    assert_equal('downcased@example.com', user.email_address)
  end

  test 'downcases and strips username' do
    user = User.new(username: ' TestUser ')
    assert_equal('testuser', user.username)
  end

  test 'requires username' do
    user = User.new(email_address: 'test@example.com', password: 'password123')
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test 'validates username format' do
    user = users(:one)
    user.username = 'invalid user!'
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test 'validates username length' do
    user = users(:one)
    user.username = 'ab'
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test 'validates password minimum length' do
    user = User.new(username: 'newuser', email_address: 'new@example.com', password: 'short')
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test 'validates bio max length' do
    user = users(:one)
    user.bio = 'a' * 161
    assert_not user.valid?
    assert user.errors[:bio].any?
  end
end
