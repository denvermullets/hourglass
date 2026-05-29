require 'test_helper'

class MtasksOutboundEmitterJobTest < ActiveJob::TestCase # rubocop:disable Metrics/ClassLength
  setup do
    @integration = server_integrations(:jait_one)
    @channel = channels(:general)
    @message = messages(:one)
    @link = MtasksLink.create!(
      link_type: MtasksLink::PROJECT_CHANNEL,
      server_integration: @integration, channel: @channel,
      mtasks_team_id: 21, mtasks_project_id: 7,
      created_by_user: users(:one)
    )
  end

  test 'logs a TODO line for known link events' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'link.created',
        integration_id: 1,
        data: { link_type: 'project_channel', mtasks_project_id: 7, hourglass_channel_id: 3 }
      )
    end
    assert_match(/TODO emit link\.created/, captured)
  end

  test 'warns and does nothing for unsupported event types' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'totally.unknown', integration_id: 1, data: {}
      )
    end
    assert_match(/unsupported event/, captured)
  end

  test 'message.created posts a project comment and writes back mtasks_comment_id' do
    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :post_project_comment, lambda { |**kw|
      calls << kw
      { 'id' => 555 }
    }) do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.created', message_id: @message.id, link_id: @link.id
      )
    end

    assert_equal 1, calls.size
    assert_equal 21, calls.first[:team_id]
    assert_equal 7, calls.first[:project_id]
    assert_equal @message.body, calls.first[:body]
    assert_equal @message.id.to_s, calls.first[:idempotency_key].to_s

    @message.reload
    assert_equal 555, @message.data['mtasks_comment_id']
    assert_equal @link.id, @message.data['mtasks_link_id']
  end

  test 'message.created posts an issue comment when link is issue_thread' do
    issue_link = MtasksLink.create!(
      link_type: MtasksLink::ISSUE_THREAD,
      server_integration: @integration, thread: @message,
      mtasks_team_id: 21, mtasks_issue_id: 91,
      created_by_user: users(:one)
    )
    reply = @channel.messages.create!(
      user: users(:one), body: 'a reply', message_type: :regular,
      parent_message: @message
    )

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :post_issue_comment, lambda { |**kw|
      calls << kw
      { 'id' => 999 }
    }) do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.created', message_id: reply.id, link_id: issue_link.id
      )
    end

    assert_equal 1, calls.size
    assert_equal 91, calls.first[:issue_id]
    assert_equal 999, reply.reload.data['mtasks_comment_id']
  end

  test 'message.updated calls update_comment when comment_id is stored' do
    @message.update!(data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => @link.id })

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :update_comment, lambda { |**kw|
      calls << kw
      { 'id' => 555 }
    }) do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.updated', message_id: @message.id)
    end

    assert_equal 1, calls.size
    assert_equal 21, calls.first[:team_id]
    assert_equal 555, calls.first[:comment_id]
    assert_equal @message.body, calls.first[:body]
  end

  test 'message.deleted calls delete_comment and clears stored metadata' do
    @message.update!(data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => @link.id })

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :delete_comment, lambda { |**kw|
      calls << kw
      nil
    }) do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.deleted', message_id: @message.id)
    end

    assert_equal 1, calls.size
    @message.reload
    assert_nil @message.data['mtasks_comment_id']
    assert_nil @message.data['mtasks_link_id']
  end

  test 'message.created with missing message warns and returns' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.created', message_id: 0, link_id: @link.id
      )
    end
    assert_match(/missing message/, captured)
  end

  test 'message.created with missing link warns and returns' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.created', message_id: @message.id, link_id: 0
      )
    end
    assert_match(/missing link/, captured)
  end

  test 'message.updated without stored comment_id warns and returns' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.updated', message_id: @message.id)
    end
    assert_match(%r{missing comment/link metadata}, captured)
  end

  test 'message.pinned posts a project decision and stores mtasks_decision_id' do
    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :post_project_decision, lambda { |**kw|
      calls << kw
      { 'id' => 777 }
    }) do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.pinned', message_id: @message.id, link_id: @link.id
      )
    end

    assert_equal 1, calls.size
    assert_equal 7, calls.first[:project_id]
    assert_equal "#{@message.id}-decision", calls.first[:idempotency_key]

    @message.reload
    assert_equal 777, @message.data['mtasks_decision_id']
    assert_equal @link.id, @message.data['mtasks_decision_link_id']
  end

  test 'message.pinned posts an issue decision when link is issue_thread' do
    issue_link = MtasksLink.create!(
      link_type: MtasksLink::ISSUE_THREAD,
      server_integration: @integration, thread: @message,
      mtasks_team_id: 21, mtasks_issue_id: 91,
      created_by_user: users(:one)
    )

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :post_issue_decision, lambda { |**kw|
      calls << kw
      { 'id' => 888 }
    }) do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'message.pinned', message_id: @message.id, link_id: issue_link.id
      )
    end

    assert_equal 1, calls.size
    assert_equal 91, calls.first[:issue_id]
    assert_equal 888, @message.reload.data['mtasks_decision_id']
  end

  test 'message.unpinned calls delete_project_decision and clears stored metadata' do
    @message.update!(data: { 'mtasks_decision_id' => 777, 'mtasks_decision_link_id' => @link.id })

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :delete_project_decision, lambda { |**kw|
      calls << kw
      nil
    }) do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.unpinned', message_id: @message.id)
    end

    assert_equal 1, calls.size
    assert_equal 7, calls.first[:project_id]
    assert_equal 777, calls.first[:decision_id]
    @message.reload
    assert_nil @message.data['mtasks_decision_id']
    assert_nil @message.data['mtasks_decision_link_id']
  end

  test 'message.unpinned uses delete_issue_decision when link is issue_thread' do
    issue_link = MtasksLink.create!(
      link_type: MtasksLink::ISSUE_THREAD,
      server_integration: @integration, thread: @message,
      mtasks_team_id: 21, mtasks_issue_id: 91,
      created_by_user: users(:one)
    )
    @message.update!(data: { 'mtasks_decision_id' => 888, 'mtasks_decision_link_id' => issue_link.id })

    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :delete_issue_decision, lambda { |**kw|
      calls << kw
      nil
    }) do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.unpinned', message_id: @message.id)
    end

    assert_equal 1, calls.size
    assert_equal 91, calls.first[:issue_id]
    assert_equal 888, calls.first[:decision_id]
  end

  test 'message.unpinned without stored decision_id warns and returns' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(event_type: 'message.unpinned', message_id: @message.id)
    end
    assert_match(%r{missing decision/link metadata}, captured)
  end

  test 'user.mentioned calls notify_user with a stable idempotency key' do
    calls = []
    with_stubbed_instance_method(Jait::ApiClient, :notify_user, lambda { |**kw|
      calls << kw
      nil
    }) do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'user.mentioned',
        message_id: @message.id,
        integration_id: @integration.id,
        mtasks_user_id: 5001
      )
    end

    assert_equal 1, calls.size
    assert_equal 5001, calls.first[:mtasks_user_id]
    assert_equal @message.body, calls.first[:body]
    assert_equal @message.id, calls.first[:source_message_id]
    assert_equal "mention-#{@message.id}-5001", calls.first[:idempotency_key]
  end

  test 'user.mentioned warns when integration is missing' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'user.mentioned',
        message_id: @message.id, integration_id: 0, mtasks_user_id: 5001
      )
    end
    assert_match(/user\.mentioned missing integration/, captured)
  end

  test 'user.mentioned warns when message is missing' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        event_type: 'user.mentioned',
        message_id: 0, integration_id: @integration.id, mtasks_user_id: 5001
      )
    end
    assert_match(/user\.mentioned missing message/, captured)
  end

  private

  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  # Like StubbingHelper#with_stubbed_class_method but for instance methods.
  def with_stubbed_instance_method(klass, method_name, callable)
    alias_target = :"_stubbed_orig_#{method_name}"
    klass.alias_method(alias_target, method_name)
    klass.define_method(method_name) { |**kw| callable.call(**kw) }
    yield
  ensure
    klass.alias_method(method_name, alias_target)
    klass.send(:remove_method, alias_target)
  end
end
