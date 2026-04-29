class MtasksLink < ApplicationRecord
  PROJECT_CHANNEL = 'project_channel'.freeze
  ISSUE_THREAD = 'issue_thread'.freeze
  LINK_TYPES = [PROJECT_CHANNEL, ISSUE_THREAD].freeze

  belongs_to :server_integration
  belongs_to :channel, optional: true
  belongs_to :thread, class_name: 'Message', optional: true
  belongs_to :created_by_user, class_name: 'User'

  validates :link_type, presence: true, inclusion: { in: LINK_TYPES }
  validates :mtasks_team_id, presence: true
  validate :columns_match_link_type

  scope :project_channels, -> { where(link_type: PROJECT_CHANNEL) }
  scope :issue_threads, -> { where(link_type: ISSUE_THREAD) }

  def project_channel?
    link_type == PROJECT_CHANNEL
  end

  def issue_thread?
    link_type == ISSUE_THREAD
  end

  private

  def columns_match_link_type
    case link_type
    when PROJECT_CHANNEL then validate_project_channel_columns
    when ISSUE_THREAD then validate_issue_thread_columns
    end
  end

  def validate_project_channel_columns
    errors.add(:channel_id, 'is required for project_channel link') if channel_id.blank?
    errors.add(:mtasks_project_id, 'is required for project_channel link') if mtasks_project_id.blank?
    errors.add(:thread_id, 'must be blank for project_channel link') if thread_id.present?
    errors.add(:mtasks_issue_id, 'must be blank for project_channel link') if mtasks_issue_id.present?
  end

  def validate_issue_thread_columns
    errors.add(:thread_id, 'is required for issue_thread link') if thread_id.blank?
    errors.add(:mtasks_issue_id, 'is required for issue_thread link') if mtasks_issue_id.blank?
    errors.add(:channel_id, 'must be blank for issue_thread link') if channel_id.present?
    errors.add(:mtasks_project_id, 'must be blank for issue_thread link') if mtasks_project_id.present?
  end
end
