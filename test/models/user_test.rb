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

  test 'unread_server_ids is empty when no channel has messages' do
    assert_empty users(:two).unread_server_ids
  end

  test 'unread_server_ids includes a server whose channel was never read' do
    channels(:general).update!(last_message_at: Time.current)
    assert_equal Set[servers(:one).id], users(:two).unread_server_ids
  end

  test 'unread_server_ids excludes a server whose channels are all read' do
    channels(:general).update!(last_message_at: 1.hour.ago)
    ChannelMembership.create!(user: users(:two), channel: channels(:general), last_read_at: Time.current)
    assert_empty users(:two).unread_server_ids
  end

  test 'unread_server_ids includes a server read before the latest message' do
    ChannelMembership.create!(user: users(:two), channel: channels(:general), last_read_at: 1.hour.ago)
    channels(:general).update!(last_message_at: Time.current)
    assert_equal Set[servers(:one).id], users(:two).unread_server_ids
  end

  test 'unread_server_ids ignores private channels the user cannot see' do
    private_channel = servers(:one).channels.create!(name: 'secret', is_private: true, last_message_at: Time.current)
    ChannelMembership.create!(user: users(:one), channel: private_channel)
    assert_empty users(:two).unread_server_ids
    assert_equal Set[servers(:one).id], users(:one).unread_server_ids
  end
end
