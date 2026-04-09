class ConversationMembership < ApplicationRecord
  belongs_to :user
  belongs_to :conversation

  validates :user_id, uniqueness: { scope: :conversation_id }

  def mark_read!
    update!(last_read_at: Time.current)
  end
end
