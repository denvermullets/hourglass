class Membership < ApplicationRecord
  enum :role, { owner: 0, admin: 1, moderator: 2, member: 3 }, default: :member

  belongs_to :user
  belongs_to :server

  validates :user_id, uniqueness: { scope: :server_id, message: 'is already a member of this server' }
  validates :role, presence: true
  validates :joined_at, presence: true
  validates :nickname, length: { maximum: 32 }, allow_blank: true

  before_validation :set_joined_at, on: :create

  def at_least?(check_role)
    self.class.roles[role] <= self.class.roles[check_role.to_s]
  end

  def can_manage_channels?
    at_least?(:moderator)
  end

  def can_manage_members?
    at_least?(:admin)
  end

  def can_manage_server?
    at_least?(:admin)
  end

  def can_delete_server?
    owner?
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
