require 'test_helper'

class MessagesHelperTest < ActionView::TestCase
  setup do
    @user = users(:one)
    Current.session = @user.sessions.create!
  end

  teardown do
    Current.session = nil
  end

  test 'renders a markdown message through RenderService' do
    message = Message.new(
      channel: channels(:general), user: @user,
      body: '**bold** @usertwo #general', data: { 'format' => 'markdown' }
    )

    html = sanitize_message(message)

    assert_includes html, '<strong>bold</strong>'
    assert_includes html, '<span class="mention" data-mention-username="usertwo">@usertwo</span>'
    assert_includes html, 'class="channel-mention"'
  end

  test 'renders a legacy HTML message through the sanitize chain' do
    message = Message.new(
      channel: channels(:general), user: @user,
      body: '<span class="editor-mention" data-mention-username="usertwo">@usertwo</span>'
    )

    html = sanitize_message(message)

    assert_includes html, 'class="mention"'
    refute_includes html, 'editor-mention'
  end

  test 'returns empty string for a blank markdown body' do
    message = Message.new(
      channel: channels(:general), user: @user, body: '', data: { 'format' => 'markdown' }
    )

    assert_equal '', sanitize_message(message)
  end
end
