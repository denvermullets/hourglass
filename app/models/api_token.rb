require 'digest'
require 'securerandom'

class ApiToken < ApplicationRecord
  ALLOWED_SCOPES = %w[read write].freeze

  belongs_to :user
  belongs_to :server, optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_must_be_allowed

  scope :active, -> { where(revoked_at: nil) }

  def self.generate_for(user, name:, server: nil, scopes: %w[read write])
    raw = SecureRandom.urlsafe_base64(32)
    token = create!(
      user: user,
      server: server,
      name: name,
      scopes: scopes,
      token_digest: digest(raw)
    )
    [token, raw]
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    active.find_by(token_digest: digest(raw))
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end

  def has_scope?(scope) # rubocop:disable Naming/PredicatePrefix
    scopes.include?(scope.to_s)
  end

  def digest_preview
    token_digest.last(4)
  end

  private

  def scopes_must_be_allowed
    return if scopes.is_a?(Array) && scopes.all? { |s| ALLOWED_SCOPES.include?(s) }

    errors.add(:scopes, "must be a subset of #{ALLOWED_SCOPES.join(', ')}")
  end
end
