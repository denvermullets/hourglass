class MtasksUserMap < ApplicationRecord
  belongs_to :hourglass_user, class_name: 'User'

  validates :hourglass_user_id, uniqueness: true
  validates :mtasks_user_id, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
end
