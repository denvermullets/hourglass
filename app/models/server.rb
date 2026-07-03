class Server < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :categories, -> { active.order(position: :asc) }, dependent: :destroy
  has_many :all_categories, -> { order(position: :asc) }, class_name: 'Category', dependent: false
  has_many :channels, dependent: :destroy
  has_many :server_integrations, dependent: :destroy
  has_many :api_tokens, dependent: :nullify

  has_one_attached :icon

  def jait_integration
    server_integrations.enabled.for_kind(ServerIntegration::KIND_JAIT).first
  end

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :invite_code, presence: true, uniqueness: true

  before_validation :generate_invite_code, on: :create

  def regenerate_invite_code!
    update!(invite_code: self.class.send(:generate_unique_invite_code))
  end

  def permission(key)
    settings.dig('permissions', key.to_s)
  end

  def members_can_create_channels?
    permission('members_can_create_channels') == true
  end

  def members_can_create_categories?
    permission('members_can_create_categories') == true
  end

  def membership_for(user)
    memberships.find_by(user: user)
  end

  # DB-backed presence: members seen within the online window (see ApplicationController#touch_last_seen).
  def online_count
    users.where('last_seen_at > ?', 45.seconds.ago).count
  end

  private

  def generate_invite_code
    self.invite_code ||= self.class.send(:generate_unique_invite_code)
  end

  class << self
    private

    def generate_unique_invite_code
      loop do
        code = SecureRandom.alphanumeric(8)
        break code unless exists?(invite_code: code)
      end
    end
  end
end
