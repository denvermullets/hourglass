class Conversation < ApplicationRecord
  has_many :conversation_memberships, dependent: :destroy
  has_many :members, through: :conversation_memberships, source: :user
  has_many :messages, dependent: :destroy

  scope :ordered, -> { order(Arel.sql('COALESCE(conversations.last_message_at, conversations.created_at) DESC')) }
  scope :for_user, ->(user) { joins(:conversation_memberships).where(conversation_memberships: { user_id: user.id }) }

  def display_name(current_user)
    return name if name.present?

    other = members.where.not(id: current_user.id)
    other.any? ? other.map(&:username).sort.join(', ') : current_user.username
  end

  def one_on_one?
    !is_group
  end

  def other_user(current_user)
    members.where.not(id: current_user.id).first
  end
end
