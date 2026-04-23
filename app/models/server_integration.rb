class ServerIntegration < ApplicationRecord
  KIND_JAIT = 'jait'.freeze

  belongs_to :server

  validates :kind, presence: true, uniqueness: { scope: :server_id }
  validates :base_url, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :for_kind, ->(kind) { where(kind: kind) }

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

  def client
    @client ||= Jait::ApiClient.new(self)
  end
end
