class Category < ApplicationRecord
  belongs_to :server
  has_many :channels, -> { order(position: :asc) }, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(position: :asc) }
end
