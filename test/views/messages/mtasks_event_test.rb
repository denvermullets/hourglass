require 'test_helper'

class MtasksEventViewTest < ActionView::TestCase
  setup do
    @user = users(:one)
    Current.session = @user.sessions.create!
    @channel = channels(:general)
  end

  teardown do
    Current.session = nil
  end

  def build_message(data)
    @channel.messages.create!(
      user: @user,
      body: 'fallback summary',
      message_type: :system,
      data: data
    )
  end

  test 'renders issue.created card with all fields' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.created',
      'actor_email' => @user.email_address,
      'actor_username' => 'denvermullets',
      'identifier' => 'BZL-204',
      'title' => 'Pricing page hero copy',
      'project_name' => 'design-rebrand',
      'team_slug' => 'design',
      'priority' => 'med',
      'status_lane_name' => 'TODO',
      'assignee_username' => 'matt',
      'labels' => [{ 'name' => 'copy' }, { 'name' => 'marketing-site' }]
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'JAIT', html
    assert_match 'issue.created', html
    assert_match 'design-rebrand', html
    assert_match '#general', html
    assert_match 'BZL-204', html
    assert_match 'Pricing page hero copy', html
    assert_match 'TODO', html
    assert_match 'med', html
    assert_match 'copy, marketing-site', html
    assert_match 'open in jait', html
  end

  test 'renders issue.commented card with quoted body' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.commented',
      'actor_email' => @user.email_address,
      'actor_username' => 'layshock',
      'identifier' => 'BZL-188',
      'title' => 'Onboarding flow image compression',
      'comment_body' => 'checked the artifacts on safari iOS'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'commented on', html
    assert_match 'Onboarding flow image compression', html
    assert_match 'checked the artifacts on safari iOS', html
  end

  test 'renders issue.status_changed card' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.status_changed',
      'actor_username' => 'andrew',
      'identifier' => 'CLM-49',
      'title' => 'decide if viewers need accounts',
      'from_lane_name' => 'IN PROGRESS',
      'to_lane_name' => 'DONE'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'moved', html
    assert_match 'IN PROGRESS', html
    assert_match 'DONE', html
  end

  test 'renders issue.assigned card' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.assigned',
      'actor_username' => 'denvermullets',
      'identifier' => 'BZL-301',
      'title' => 'Stripe webhook retry logic',
      'assignee_username' => 'andrew'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'assigned to', html
    assert_match '@andrew', html
    assert_match 'BZL-301', html
  end

  test 'renders issue.branch_linked card' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.branch_linked',
      'actor_username' => 'matt',
      'identifier' => 'BZL-204',
      'title' => 'Pricing page hero copy',
      'branch_name' => 'matt/bzl-204-hero-copy',
      'branch_url' => 'https://github.com/example/repo/tree/matt/bzl-204-hero-copy'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'matt/bzl-204-hero-copy', html
    assert_match 'github.com/example/repo', html
  end

  test 'renders project.commented card without an issue identifier' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'project.commented',
      'actor_username' => 'casey',
      'project_name' => 'design-rebrand',
      'comment_body' => 'kicking off discussion here'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'project.commented', html
    assert_match 'commented on', html
    assert_match 'design-rebrand', html
    assert_match 'kicking off discussion here', html
  end

  test 'falls back to message body when event_type partial does not exist' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.something_unknown'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match 'fallback summary', html
  end

  test 'resolves actor by email to a real Hourglass user' do
    message = build_message(
      'source' => 'mtasks',
      'event_type' => 'issue.created',
      'actor_email' => @user.email_address,
      'actor_username' => 'overridden_jait_handle',
      'identifier' => 'BZL-1',
      'title' => 't'
    )
    html = render(partial: 'messages/mtasks_event', locals: { message: message })
    assert_match @user.username, html
    assert_no_match(/overridden_jait_handle/, html)
  end
end
