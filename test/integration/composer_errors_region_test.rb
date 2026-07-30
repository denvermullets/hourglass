require 'test_helper'

# Every composer must ship the error region on page load, since messages#create /
# conversation_messages#create address it by id when a send is rejected. A missing region
# means the turbo_stream replace silently no-ops and the author is back to a blank 422.
class ComposerErrorsRegionTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test 'channel composer renders its error region' do
    get server_channel_path(servers(:one), channels(:general))
    assert_response :success
    assert_select "##{composer_errors_id(channel: channels(:general))}"
  end

  test 'channel thread composer renders its error region' do
    get server_channel_message_thread_path(servers(:one), channels(:general), messages(:one))
    assert_response :success
    assert_select "##{composer_errors_id(parent_message_id: messages(:one).id)}"
  end

  test 'conversation composer renders its error region' do
    conversation = create_conversation
    get conversation_path(conversation)
    assert_response :success
    assert_select "##{composer_errors_id(conversation: conversation)}"
  end

  test 'conversation thread composer renders its error region' do
    conversation = create_conversation
    parent = conversation.messages.create!(user: users(:one), body: 'thread root', message_type: :regular)

    get conversation_message_thread_path(conversation, parent)
    assert_response :success
    assert_select "##{composer_errors_id(parent_message_id: parent.id)}"
  end

  test 'a rejected send paints the channel composer error region' do
    post server_channel_messages_path(servers(:one), channels(:general)),
         params: { message: { body: 'x' * (Message::BODY_MAX_LENGTH + 1) } }

    assert_response :unprocessable_entity
    assert_match 'action="replace"', response.body
    assert_match composer_errors_id(channel: channels(:general)), response.body
    assert_match "maximum is #{Message::BODY_MAX_LENGTH} characters", response.body
  end

  test 'a rejected reply paints the thread composer error region, not the channel one' do
    parent = messages(:one)
    post server_channel_messages_path(servers(:one), channels(:general)),
         params: { message: { body: 'x' * (Message::BODY_MAX_LENGTH + 1), parent_message_id: parent.id } }

    assert_response :unprocessable_entity
    assert_match composer_errors_id(parent_message_id: parent.id), response.body
    assert_no_match(/composer_errors_channel/, response.body)
  end

  test 'a rejected DM send paints the conversation composer error region' do
    conversation = create_conversation
    post conversation_messages_path(conversation),
         params: { message: { body: 'x' * (Message::BODY_MAX_LENGTH + 1) } }

    assert_response :unprocessable_entity
    assert_match composer_errors_id(conversation: conversation), response.body
  end

  test 'a body at the limit still sends' do
    assert_difference 'Message.count' do
      post server_channel_messages_path(servers(:one), channels(:general)),
           params: { message: { body: 'x' * Message::BODY_MAX_LENGTH } }
    end
    assert_response :ok
  end

  private

  # No conversation fixtures exist yet; a two-person DM is the minimum this needs.
  def create_conversation
    Conversation.create!.tap do |conversation|
      [users(:one), users(:two)].each do |user|
        conversation.conversation_memberships.create!(user: user)
      end
    end
  end

  def composer_errors_id(**)
    ApplicationController.helpers.composer_errors_id(**)
  end
end
