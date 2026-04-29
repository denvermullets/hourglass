class MtasksIssueCache < ApplicationRecord
  self.primary_key = 'mtasks_issue_id'

  validates :mtasks_issue_id, presence: true
  validates :identifier, presence: true

  scope :active, -> { where(deleted_at: nil) }

  def deleted?
    deleted_at.present?
  end
end
