require 'test_helper'

class MtasksOutboundEmitterJobTest < ActiveJob::TestCase
  test 'logs a TODO line for known events' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        integration_id: 1, event_type: 'link.created',
        data: { link_type: 'project_channel', mtasks_project_id: 7, hourglass_channel_id: 3 }
      )
    end
    assert_match(/TODO emit link\.created/, captured)
  end

  test 'warns and does nothing for unsupported event types' do
    captured = capture_log do
      MtasksOutboundEmitterJob.perform_now(
        integration_id: 1, event_type: 'totally.unknown', data: {}
      )
    end
    assert_match(/unsupported event/, captured)
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
end
