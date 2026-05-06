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

  test 'mtasks_open_in_jait_url returns the source_url that JAIT sent' do
    url = mtasks_open_in_jait_url('source_url' => 'https://jait.example.com/teams/HOUR/issues/BZL-204')
    assert_equal 'https://jait.example.com/teams/HOUR/issues/BZL-204', url
  end

  test 'mtasks_open_in_jait_url is nil when source_url missing' do
    assert_nil mtasks_open_in_jait_url({})
    assert_nil mtasks_open_in_jait_url('source_url' => '')
    assert_nil mtasks_open_in_jait_url('source_url' => '   ')
  end

  # -- mtasks_view_source --

  test 'mtasks_view_source returns view-issue link for issue events with a thread' do
    integration = server_integrations(:jait_one)
    parent = @channel.messages.create!(user: @user, body: 'parent', message_type: :regular)
    MtasksLink.create!(
      link_type: MtasksLink::ISSUE_THREAD,
      server_integration: integration, created_by_user: @user,
      mtasks_team_id: 21, mtasks_issue_id: 999, thread: parent
    )

    link = mtasks_view_source('event_type' => 'issue.commented', 'issue_id' => 999)
    assert_equal 'view issue', link[:label]
    assert_equal server_channel_message_thread_path(@server, @channel, parent), link[:path]
  end

  test 'mtasks_view_source is nil for project events (open-in-jait covers them)' do
    assert_nil mtasks_view_source('event_type' => 'project.commented', 'project_id' => 42)
  end

  test 'mtasks_view_source is nil when no thread link exists' do
    assert_nil mtasks_view_source('event_type' => 'issue.created', 'issue_id' => 999_999)
    assert_nil mtasks_view_source('event_type' => 'unknown.event')
    assert_nil mtasks_view_source({})
  end

  # -- mtasks_event_partial --

  test 'mtasks_event_partial converts event type to a partial path' do
    assert_equal 'messages/mtasks_event/issue_created', mtasks_event_partial('issue.created')
    assert_equal 'messages/mtasks_event/issue_status_changed', mtasks_event_partial('issue.status_changed')
    assert_equal 'messages/mtasks_event/project_commented', mtasks_event_partial('project.commented')
  end
end
