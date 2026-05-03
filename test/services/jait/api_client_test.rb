require 'test_helper'

module Jait
  class ApiClientTest < ActiveSupport::TestCase
    setup do
      @integration = server_integrations(:jait_one)
      @client = Jait::ApiClient.new(@integration)
    end

    def stub_get(value)
      @client.define_singleton_method(:get) { |_path| value.is_a?(Proc) ? value.call : value }
    end

    test 'fetch_projects unwraps {"projects": [...]} envelope' do
      stub_get({ 'projects' => [{ 'id' => 1, 'name' => 'Alpha' }] })
      result = @client.fetch_projects(21)
      assert_equal 1, result.size
      assert_equal 'Alpha', result.first['name']
    end

    test 'fetch_projects returns the array as-is when no envelope' do
      stub_get([{ 'id' => 1, 'name' => 'Alpha' }])
      result = @client.fetch_projects(21)
      assert_equal 'Alpha', result.first['name']
    end

    test 'fetch_projects propagates Jait::ApiClient::NotFound' do
      stub_get(-> { raise Jait::ApiClient::NotFound, 'gone' })
      assert_raises(Jait::ApiClient::NotFound) { @client.fetch_projects(21) }
    end

    test 'create_issue posts to the project issues path with title and creator_email' do
      captured = stub_request_capture(value: { 'id' => 9001, 'identifier' => 'HOUR-9001' })
      result = @client.create_issue(team_id: 21, project_id: 7, title: 'Add billing fields',
                                    creator: 'one@example.com')

      assert_equal 9001, result['id']
      assert_equal :post, captured[:method]
      assert_equal '/api/v1/teams/21/projects/7/issues', captured[:path]
      assert_equal({ title: 'Add billing fields', creator_email: 'one@example.com' }, captured[:body])
    end

    test 'post_issue_comment hits the issue comments path with idempotency key' do
      captured = stub_request_capture(value: { 'id' => 42 })
      result = @client.post_issue_comment(team_id: 21, issue_id: 91, body: 'hi', idempotency_key: 1234)

      assert_equal 42, result['id']
      assert_equal :post, captured[:method]
      assert_equal '/api/v1/teams/21/issues/91/comments', captured[:path]
      assert_equal({ body: 'hi' }, captured[:body])
      assert_equal '1234', captured[:headers]['Idempotency-Key']
    end

    test 'post_project_comment hits the project comments path with idempotency key' do
      captured = stub_request_capture(value: { 'id' => 7 })
      result = @client.post_project_comment(team_id: 21, project_id: 7, body: 'hi', idempotency_key: 999)

      assert_equal 7, result['id']
      assert_equal :post, captured[:method]
      assert_equal '/api/v1/teams/21/projects/7/comments', captured[:path]
      assert_equal '999', captured[:headers]['Idempotency-Key']
    end

    test 'update_comment issues a PUT' do
      captured = stub_request_capture(value: { 'id' => 555 })
      @client.update_comment(team_id: 21, comment_id: 555, body: 'edited')

      assert_equal :put, captured[:method]
      assert_equal '/api/v1/teams/21/comments/555', captured[:path]
      assert_equal({ body: 'edited' }, captured[:body])
    end

    test 'delete_comment issues a DELETE' do
      captured = stub_request_capture(value: nil)
      @client.delete_comment(team_id: 21, comment_id: 555)

      assert_equal :delete, captured[:method]
      assert_equal '/api/v1/teams/21/comments/555', captured[:path]
    end

    test 'post_issue_decision hits the issue decisions path' do
      captured = stub_request_capture(value: { 'id' => 42 })
      decision = {
        hourglass_message_id: 5, body_snapshot: 'do it',
        pinned_at: '2026-05-03T10:00:00Z', pinned_by_email: 'a@b.com'
      }
      @client.post_issue_decision(
        team_id: 21, issue_id: 91, decision: decision, idempotency_key: 'm-1-decision'
      )

      assert_equal :post, captured[:method]
      assert_equal '/api/v1/teams/21/issues/91/decisions', captured[:path]
      assert_equal decision, captured[:body]
      assert_equal 'm-1-decision', captured[:headers]['Idempotency-Key']
    end

    test 'post_project_decision hits the project decisions path' do
      captured = stub_request_capture(value: { 'id' => 7 })
      @client.post_project_decision(
        team_id: 21, project_id: 7,
        decision: { hourglass_message_id: 5, body_snapshot: 'do it' },
        idempotency_key: 'm-1-decision'
      )

      assert_equal :post, captured[:method]
      assert_equal '/api/v1/teams/21/projects/7/decisions', captured[:path]
    end

    test 'delete_issue_decision issues a DELETE on the nested path' do
      captured = stub_request_capture(value: nil)
      @client.delete_issue_decision(team_id: 21, issue_id: 91, decision_id: 555)

      assert_equal :delete, captured[:method]
      assert_equal '/api/v1/teams/21/issues/91/decisions/555', captured[:path]
    end

    test 'delete_project_decision issues a DELETE on the nested path' do
      captured = stub_request_capture(value: nil)
      @client.delete_project_decision(team_id: 21, project_id: 7, decision_id: 555)

      assert_equal :delete, captured[:method]
      assert_equal '/api/v1/teams/21/projects/7/decisions/555', captured[:path]
    end

    private

    def stub_request_capture(value:)
      captured = {}
      @client.define_singleton_method(:request) do |method, path, body: nil, headers: {}|
        captured[:method] = method
        captured[:path] = path
        captured[:body] = body
        captured[:headers] = headers
        value
      end
      captured
    end
  end
end
