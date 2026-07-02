class Conversations::MarkReadService < Service
  def initialize(conversation:, user:)
    @conversation = conversation
    @user = user
  end

  def call
    membership = ConversationMembership.find_or_create_by!(
      user: @user,
      conversation: @conversation
    )
    membership.mark_read!

    membership
  end
end
