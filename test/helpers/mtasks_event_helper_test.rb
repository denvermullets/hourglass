require 'test_helper'

class MtasksEventHelperTest < ActionView::TestCase
  setup do
    @user = users(:one)
    @channel = channels(:general)
    @server = @channel.server
  end

  # -- mtasks_actor_user --

  test 'mtasks_actor_user returns User when actor_email matches' do
    user = mtasks_actor_user('actor_email' => @user.email_address)
    assert_equal @user, user
  end

  test 'mtasks_actor_user is case-insensitive' do
    user = mtasks_actor_user('actor_email' => @user.email_address.upcase)
    assert_equal @user, user
  end

  test 'mtasks_actor_user returns nil when actor_email missing' do
    assert_nil mtasks_actor_user({})
    assert_nil mtasks_actor_user('actor_email' => '')
  end

  test 'mtasks_actor_user returns nil when no User matches' do
    assert_nil mtasks_actor_user('actor_email' => 'nobody@example.com')
  end

  # -- mtasks_open_in_jait_url --

  test 'mtasks_open_in_jait_url builds the issue URL' do
    integration = server_integrations(:jait_one)
    message = @channel.messages.create!(user: @user, body: 'x', message_type: :system)
    url = mtasks_open_in_jait_url(message,
                                  'team_slug' => 'design', 'identifier' => 'BZL-204')
    assert_equal "#{integration.base_url}/teams/design/issues/BZL-204", url
  end

  test 'mtasks_open_in_jait_url is nil when integration missing' do
    other_server = Server.create!(name: 'lonely', invite_code: SecureRandom.hex(8), owner: @user)
    other_channel = other_server.channels.create!(name: 'g', channel_type: :text, position: 0)
    message = other_channel.messages.create!(user: @user, body: 'x', message_type: :system)
    assert_nil mtasks_open_in_jait_url(message,
                                       'team_slug' => 'design', 'identifier' => 'BZL-204')
  end

  test 'mtasks_open_in_jait_url is nil when team_slug or identifier missing' do
    message = @channel.messages.create!(user: @user, body: 'x', message_type: :system)
    assert_nil mtasks_open_in_jait_url(message, 'identifier' => 'BZL-204')
    assert_nil mtasks_open_in_jait_url(message, 'team_slug' => 'design')
  end

  # -- mtasks_view_issue_path --

  test 'mtasks_view_issue_path returns thread path when issue link exists' do
    integration = server_integrations(:jait_one)
    parent = @channel.messages.create!(user: @user, body: 'parent', message_type: :regular)
    MtasksLink.create!(
      link_type: MtasksLink::ISSUE_THREAD,
      server_integration: integration,
      created_by_user: @user,
      mtasks_team_id: 21,
      mtasks_issue_id: 999,
      thread: parent
    )

    path = mtasks_view_issue_path('issue_id' => 999)
    assert_equal server_channel_message_thread_path(@server, @channel, parent), path
  end

  test 'mtasks_view_issue_path is nil when no link exists' do
    assert_nil mtasks_view_issue_path('issue_id' => 999_999)
    assert_nil mtasks_view_issue_path({})
  end

  # -- mtasks_event_partial --

  test 'mtasks_event_partial converts event type to a partial path' do
    assert_equal 'messages/mtasks_event/issue_created', mtasks_event_partial('issue.created')
    assert_equal 'messages/mtasks_event/issue_status_changed', mtasks_event_partial('issue.status_changed')
    assert_equal 'messages/mtasks_event/project_commented', mtasks_event_partial('project.commented')
  end
end
