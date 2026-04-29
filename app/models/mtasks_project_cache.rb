class MtasksProjectCache < ApplicationRecord
  self.primary_key = 'mtasks_project_id'

  validates :mtasks_project_id, presence: true
  validates :name, presence: true
end
