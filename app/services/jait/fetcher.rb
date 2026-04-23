class Jait::Fetcher < Service
  TTL = 5.minutes

  def initialize(integration:, kind:, team_id:, id: nil, identifier: nil)
    @integration = integration
    @kind = kind.to_s
    @team_id = team_id
    @id = id
    @identifier = identifier
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) { fetch }
  rescue Jait::ApiClient::NotFound
    nil
  rescue Jait::ApiClient::Error => e
    Rails.logger.warn("Jait::Fetcher failed: #{e.class} #{e.message}")
    nil
  end

  private

  def fetch
    case @kind
    when 'issue'
      if @identifier
        @integration.client.fetch_issue_by_identifier(@team_id, @identifier)
      else
        @integration.client.fetch_issue(@team_id, @id)
      end
    when 'project' then @integration.client.fetch_project(@team_id, @id)
    when 'roadmap' then @integration.client.fetch_roadmap(@team_id)
    end
  end

  def cache_key
    base = "jait:#{@integration.id}:t#{@team_id}:#{@kind}"
    @identifier ? "#{base}:ident:#{@identifier}" : "#{base}:#{@id}"
  end
end
