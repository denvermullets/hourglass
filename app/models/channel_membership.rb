class ChannelMembership < ApplicationRecord
  belongs_to :user
  belongs_to :channel

  validates :user_id, uniqueness: { scope: :channel_id }

  def mark_read!
    update!(last_read_at: Time.current)
  end
end
