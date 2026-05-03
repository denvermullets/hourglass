module Messages
  module MtasksEmittable
    private

    def emittable?(message)
      message.regular? && message.data['source'] != 'mtasks' && !message.in_conversation?
    end

    def enqueue_create(message, link)
      MtasksOutboundEmitterJob.perform_later(
        event_type: 'message.created', message_id: message.id, link_id: link.id
      )
    end

    def enqueue_update(message)
      MtasksOutboundEmitterJob.perform_later(
        event_type: 'message.updated', message_id: message.id
      )
    end

    def enqueue_delete(message)
      MtasksOutboundEmitterJob.perform_later(
        event_type: 'message.deleted', message_id: message.id
      )
    end

    def enqueue_pinned(message, link)
      MtasksOutboundEmitterJob.perform_later(
        event_type: 'message.pinned', message_id: message.id, link_id: link.id
      )
    end

    def enqueue_unpinned(message)
      MtasksOutboundEmitterJob.perform_later(
        event_type: 'message.unpinned', message_id: message.id
      )
    end
  end
end
