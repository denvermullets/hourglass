require 'test_helper'

class MessagePinningTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @message = messages(:one)
  end

  test 'pinned? reflects pinned_at' do
    assert_not @message.pinned?
    @message.update!(pinned_at: Time.current)
    assert @message.pinned?
  end

  test 'pin! sets pinned_at and pinned_by' do
    freeze_time do
      @message.pin!(@other_user)
      assert_equal Time.current, @message.pinned_at
      assert_equal @other_user, @message.pinned_by
    end
  end

  test 'unpin! clears pinned_at and pinned_by' do
    @message.pin!(@other_user)
    @message.unpin!
    assert_nil @message.pinned_at
    assert_nil @message.pinned_by_id
  end

  test 'pinned scope returns only pinned, ordered ascending by created_at' do
    pinned_old = messages(:one)
    pinned_new = messages(:two)

    pinned_old.update!(pinned_at: Time.current)
    pinned_new.update!(pinned_at: Time.current)

    pinned = Message.pinned.to_a
    assert_includes pinned, pinned_old
    assert_includes pinned, pinned_new
    assert_not_includes pinned, messages(:deleted) # not pinned
    assert_equal pinned.sort_by(&:created_at), pinned, 'expected ascending created_at order'
  end

  test 'partial index on pinned_at exists and is partial' do
    indexes = ActiveRecord::Base.connection.indexes(:messages)
    pin_index = indexes.find { |i| i.name == 'index_messages_on_pinned_at_partial' }

    assert pin_index, 'expected index_messages_on_pinned_at_partial'
    assert_equal ['pinned_at'], pin_index.columns
    assert_match(/pinned_at IS NOT NULL/i, pin_index.where.to_s)
  end
end
