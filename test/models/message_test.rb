require 'test_helper'

class MessageTest < ActiveSupport::TestCase
  test 'validates body presence' do
    message = Message.new(user: users(:one), channel: channels(:general))
    assert_not message.valid?
    assert message.errors[:body].any?
  end

  test 'validates body max length' do
    message = messages(:one)
    message.body = 'a' * 4001
    assert_not message.valid?
    assert message.errors[:body].any?
  end

  test 'ordered scope returns messages in chronological order' do
    messages = Message.ordered
    assert messages.first.created_at <= messages.last.created_at
  end

  test 'not_deleted scope excludes soft-deleted messages' do
    not_deleted = Message.not_deleted
    assert_not not_deleted.include?(messages(:deleted))
    assert not_deleted.include?(messages(:one))
  end

  test 'deleted? returns true for soft-deleted messages' do
    assert messages(:deleted).deleted?
    assert_not messages(:one).deleted?
  end

  test 'edited? returns true for edited messages' do
    message = messages(:one)
    assert_not message.edited?
    message.update!(edited_at: Time.current)
    assert message.edited?
  end

  test 'owned_by? checks user ownership' do
    message = messages(:one)
    assert message.owned_by?(users(:one))
    assert_not message.owned_by?(users(:two))
  end

  test 'message_type enum' do
    message = messages(:one)
    assert message.regular?
    message.message_type = :system
    assert message.system?
  end

  test 'belongs to user' do
    assert_equal users(:one), messages(:one).user
  end

  test 'belongs to channel' do
    assert_equal channels(:general), messages(:one).channel
  end
end
