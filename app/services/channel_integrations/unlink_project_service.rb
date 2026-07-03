module ChannelIntegrations
  class UnlinkProjectService < Service
    Result = Struct.new(:ok, :error, keyword_init: true)

    def initialize(channel:, user:)
      @channel = channel
      @user = user
    end

    def call
      link = @channel.mtasks_project_link
      return Result.new(ok: true) unless link

      data = {
        link_type: 'project_channel',
        mtasks_project_id: link.mtasks_project_id,
        hourglass_channel_id: @channel.id
      }
      integration_id = link.server_integration_id
      link.destroy!
      @channel.association(:mtasks_project_link).reset

      MtasksOutboundEmitterJob.perform_later(
        integration_id: integration_id,
        event_type: 'link.removed',
        data: data
      )
      Result.new(ok: true)
    end
  end
end
