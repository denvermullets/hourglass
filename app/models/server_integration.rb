class ServerIntegration < ApplicationRecord
  KIND_JAIT = 'jait'.freeze
  WEBHOOK_SECRET_BYTE_LENGTH = 32

  belongs_to :server

  validates :kind, presence: true, uniqueness: { scope: :server_id }
  validates :base_url, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :for_kind, ->(kind) { where(kind: kind) }

  before_create :ensure_webhook_secret

  def ensure_webhook_secret!
    return webhook_secret if webhook_secret.present?

    update!(webhook_secret: SecureRandom.hex(WEBHOOK_SECRET_BYTE_LENGTH))
    webhook_secret
  end

  def rotate_webhook_secret!
    update!(webhook_secret: SecureRandom.hex(WEBHOOK_SECRET_BYTE_LENGTH))
    webhook_secret
  end

  def webhook_url(host:)
    Rails.application.routes.url_helpers.webhooks_mtasks_url(integration_id: id, host: host)
  end

  def jait?
    kind == KIND_JAIT
  end

  def configured?
    api_token.present? && discovered_teams.is_a?(Array) && discovered_teams.any?
  end

  def team_ids
    Array(discovered_teams).map { |t| t['id'].to_i }
  end

  def team_identifiers
    Array(discovered_teams).map { |t| t['identifier'].to_s }.reject(&:empty?)
  end

  def team_for(team_id)
    Array(discovered_teams).find { |t| t['id'].to_i == team_id.to_i }
  end

  def team_by_identifier(identifier)
    Array(discovered_teams).find { |t| t['identifier'].to_s == identifier.to_s }
  end

  # Re-fetch the teams this integration's token can see. Returns false (and
  # leaves discovered_teams untouched) when mtasks is unreachable or empty.
  def refresh_discovered_teams!
    teams = Jait::ApiClient.new(self).discover_teams!
    return false if teams.blank?

    update!(discovered_teams: teams, last_verified_at: Time.current)
    true
  rescue Jait::ApiClient::Error => e
    Rails.logger.warn("ServerIntegration#refresh_discovered_teams! failed: #{e.class} #{e.message}")
    false
  end

  # True when team_id belongs to this integration, refreshing discovered_teams
  # once if it isn't known yet (mtasks may have added it since the last load).
  def knows_team?(team_id)
    return false if team_id.blank?
    return true if team_for(team_id)

    refresh_discovered_teams! && team_for(team_id).present?
  end

  def client
    @client ||= Jait::ApiClient.new(self)
  end

  private

  def ensure_webhook_secret
    self.webhook_secret ||= SecureRandom.hex(WEBHOOK_SECRET_BYTE_LENGTH)
  end
end
