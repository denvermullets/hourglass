# Builds the direct turbo_stream response sent to the message author so their own
# send/edit/delete renders instantly on their screen, without waiting for the poll+morph
# refresh that other viewers get. Mirrors the targets/partials/locals used when the same
# message renders on a full page load / morph (Messages::PostCreateBroadcaster,
# Conversations::CreateMessageService, Messages::UpdateService and Messages::DeleteService).
module Messages
  module EchoResponses
    extend ActiveSupport::Concern

    private

    def created_message_streams(message, context:, **ctx)
      if message.parent_message_id.present?
        created_reply_streams(message, context: context, **ctx)
      else
        created_root_streams(message, context: context)
      end
    end

    def updated_message_streams(message, context:, **ctx)
      if message.parent_message_id.present?
        [turbo_stream.replace(message, partial: 'threads/reply',
                                       locals: { reply: message, context: context }.merge(ctx))]
      else
        [turbo_stream.replace(message, partial: 'messages/message',
                                       locals: { message: message, context: context })]
      end
    end

    # Soft-delete leaves the record in place (deleted_at set); the partials render the
    # "[message deleted]" state, and replies_count is unchanged (counter_cache only fires
    # on destroy), so a plain replace matches Messages::DeleteService.
    alias deleted_message_streams updated_message_streams

    def created_root_streams(message, context:)
      streams = []

      if new_date_separator?(message)
        streams << turbo_stream.append('messages', partial: 'messages/date_separator',
                                                   locals: { date: message.created_at })
      end

      previous = message.messageable.messages.root_messages.not_deleted
                        .where.not(id: message.id)
                        .order(created_at: :desc).first

      streams << turbo_stream.append('messages', partial: 'messages/message',
                                                 locals: { message: message, context: context,
                                                           grouped: helpers.grouped_with_previous?(message, previous) })
      streams
    end

    def created_reply_streams(message, context:, **ctx)
      parent = message.parent_message
      previous = parent.replies.not_deleted
                       .where.not(id: message.id)
                       .order(created_at: :desc).first

      reply_locals = { reply: message, context: context,
                       grouped: helpers.grouped_with_previous?(message, previous) }.merge(ctx)
      header_locals = { parent_message: parent, participant_count: parent.thread_participant_count }

      [
        turbo_stream.append('thread_replies', partial: 'threads/reply', locals: reply_locals),
        turbo_stream.replace("thread_connector_#{parent.id}", partial: 'threads/connector',
                                                              locals: { parent_message: parent }),
        turbo_stream.replace("thread_header_meta_#{parent.id}", partial: 'threads/header_meta',
                                                                locals: header_locals)
      ]
    end

    def new_date_separator?(message)
      previous_created_at = message.messageable.messages.not_deleted
                                   .where.not(id: message.id)
                                   .where('created_at < ?', message.created_at)
                                   .order(created_at: :desc)
                                   .pick(:created_at)

      previous_created_at.nil? ||
        helpers.local_date(previous_created_at) != helpers.local_date(message.created_at)
    end
  end
end
