class Channel < ApplicationRecord
  belongs_to :server
  belongs_to :category, optional: true
  has_many :channel_memberships, dependent: :destroy
  has_many :members, through: :channel_memberships, source: :user
  has_many :messages, dependent: :destroy

  enum :channel_type, { text: 0, voice: 1, announcement: 2 }

  validates :name, presence: true,
                   uniqueness: { scope: :server_id },
                   format: { with: /\A[a-z0-9]+(-[a-z0-9]+)*\z/, message: 'must be lowercase with hyphens' }
  validates :description, length: { maximum: 1024 }
  validates :topic, length: { maximum: 1024 }

  before_validation :format_name

  scope :ordered, -> { order(position: :asc) }
  scope :visible_to, lambda { |user|
    where(is_private: false)
      .or(where(id: ChannelMembership.where(user: user).select(:channel_id)))
  }

  private

  def format_name
    return if name.blank?

    self.name = name.strip
                    .downcase
                    .gsub(/[^a-z0-9\s-]/, '')
                    .gsub(/\s+/, '-')
                    .gsub(/-+/, '-')
                    .gsub(/\A-|-\z/, '')
  end
end
