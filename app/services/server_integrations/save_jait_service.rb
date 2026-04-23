class ServerIntegrations::SaveJaitService < Service
  Result = Struct.new(:flash_key, :flash_message)

  PERMITTED = %i[enabled base_url].freeze
  DEFAULT_BASE_URL = 'https://justanotherissuetracker.com'.freeze

  def initialize(integration:, params:)
    @integration = integration
    @params = params.respond_to?(:to_unsafe_h) ? params : ActionController::Parameters.new(params.to_h)
  end

  def call
    apply_attributes
    @integration.api_token.blank? ? save_without_verifying : verify_and_save
  rescue Jait::ApiClient::Unauthorized
    Result.new(:alert, token_rejected_message)
  rescue Jait::ApiClient::NotFound => e
    Result.new(:alert, e.message)
  rescue Jait::ApiClient::Error => e
    Result.new(:alert, "JAIT connection failed: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    Result.new(:alert, e.record.errors.full_messages.to_sentence)
  end

  private

  def apply_attributes
    @integration.assign_attributes(@params.permit(*PERMITTED))
    submitted_token = @params[:api_token].to_s
    @token_changed = submitted_token.present?
    @integration.api_token = submitted_token if @token_changed
    @integration.base_url = @integration.base_url.presence || DEFAULT_BASE_URL
  end

  def save_without_verifying
    @integration.save!
    Result.new(:notice, 'JAIT settings saved — add an API token to verify and enable unfurling')
  end

  def verify_and_save
    teams = Jait::ApiClient.new(@integration).discover_teams!
    raise Jait::ApiClient::NotFound, 'token has no team access' if teams.empty?

    @integration.discovered_teams = teams
    @integration.last_verified_at = Time.current
    @integration.save!
    Result.new(:notice, verified_message(teams))
  end

  def verified_message(teams)
    labels = teams.map { |t| t['identifier'] }.compact.join(', ')
    suffix = labels.present? ? ": #{labels}" : ''
    "JAIT verified — #{teams.size} team#{'s' if teams.size != 1}#{suffix}"
  end

  def token_rejected_message
    @token_changed ? 'JAIT rejected the new API token' : 'JAIT rejected the saved API token — paste a fresh one'
  end
end
