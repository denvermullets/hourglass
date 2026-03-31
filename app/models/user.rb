class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :servers, through: :memberships
  has_many :owned_servers, class_name: 'Server', foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :channel_memberships, dependent: :destroy
  has_many :joined_channels, through: :channel_memberships, source: :channel
  has_many :messages, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip.downcase }

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { in: 3..20 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: 'only allows letters, numbers, and underscores' }

  validates :email_address, presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  validates :bio, length: { maximum: 160 }, allow_blank: true
end
