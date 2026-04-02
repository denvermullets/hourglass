class Category < ApplicationRecord
  belongs_to :server
  has_many :channels, -> { order(position: :asc) }, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(position: :asc) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end
end
