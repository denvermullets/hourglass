require 'test_helper'

module Webhooks
  module Mtasks
    class IssueMessageRendererTest < ActiveSupport::TestCase
      test 'renders issue.created with title and actor' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.created',
          data: { 'issue_id' => 91, 'identifier' => 'HOUR-91', 'title' => 'fix login flow' },
          actor_username: 'ryan'
        )
        assert_equal "// issue created · HOUR-91 'fix login flow' by @ryan", body
      end

      test 'renders issue.created without title gracefully' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.created',
          data: { 'issue_id' => 91, 'identifier' => 'HOUR-91' },
          actor_username: 'ryan'
        )
        assert_equal '// issue created · HOUR-91 by @ryan', body
      end

      test 'renders issue.status_changed' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.status_changed',
          data: {
            'issue_id' => 91, 'identifier' => 'HOUR-91',
            'from_lane_name' => 'Backlog', 'to_lane_name' => 'In Progress'
          },
          actor_username: 'ryan'
        )
        assert_equal '// status · HOUR-91 Backlog → In Progress by @ryan', body
      end

      test 'renders issue.assigned with email-derived handle' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.assigned',
          data: { 'issue_id' => 91, 'identifier' => 'HOUR-91', 'assignee_email' => 'bob@example.com' },
          actor_username: 'ryan'
        )
        assert_equal '// assigned · HOUR-91 → @bob by @ryan', body
      end

      test 'falls back to user#id when assignee_email is missing' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.assigned',
          data: { 'issue_id' => 91, 'identifier' => 'HOUR-91', 'assignee_user_id' => 42 },
          actor_username: 'ryan'
        )
        assert_equal '// assigned · HOUR-91 → @user#42 by @ryan', body
      end

      test 'falls back to fallback actor when actor_username is nil' do
        body = IssueMessageRenderer.call(
          event_type: 'issue.status_changed',
          data: {
            'issue_id' => 91, 'identifier' => 'HOUR-91',
            'from_lane_name' => 'Backlog', 'to_lane_name' => 'Done'
          },
          actor_username: nil
        )
        assert_match(/by @an mtasks user/, body)
      end

      test 'returns nil for unknown event type' do
        assert_nil IssueMessageRenderer.call(event_type: 'something.weird', data: {})
      end
    end
  end
end
