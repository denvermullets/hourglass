require 'net/http'
require 'json'
require 'uri'

class Jait::ApiClient
  class Error < StandardError; end
  class Unauthorized < Error; end
  class NotFound < Error; end

  TIMEOUT = 5

  def initialize(integration)
    @integration = integration
  end

  def fetch_issue(team_id, id)
    get("/api/v1/teams/#{team_id}/issues/#{id}")
  end

  def fetch_issue_by_identifier(team_id, identifier)
    list = get("/api/v1/teams/#{team_id}/issues")
    list = list['issues'] if list.is_a?(Hash) && list['issues']
    Array(list).find { |i| i['identifier'] == identifier }
  end

  def fetch_project(team_id, id)
    get("/api/v1/teams/#{team_id}/projects/#{id}")
  end

  def fetch_roadmap(team_id)
    # JAIT has no dedicated roadmap API; synthesize it from the projects list
    # using each project's `roadmap_commitment` (now/next/later).
    projects = get("/api/v1/teams/#{team_id}/projects")
    projects = projects['projects'] if projects.is_a?(Hash) && projects['projects']
    { 'projects' => Array(projects) }
  end

  # Discovers the teams this token can access. Returns an array of
  # { "id" => Integer, "identifier" => String, "name" => String }.
  def discover_teams!
    res = get('/api/v1/teams')
    list = res.is_a?(Hash) && res['teams'] ? res['teams'] : res
    Array(list).map do |t|
      { 'id' => t['id'], 'identifier' => t['identifier'], 'name' => t['name'] }
    end
  end

  private

  attr_reader :integration

  def get(path)
    res = perform_request(path)
    handle_response(res, path)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise Error, "JAIT connection failed: #{e.message}"
  end

  def perform_request(path)
    uri = URI.join(integration.base_url.to_s, path)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{integration.api_token}"
    req['Accept'] = 'application/json'
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == 'https',
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(req) }
  end

  def handle_response(res, path)
    case res.code.to_i
    when 200 then JSON.parse(res.body)
    when 401, 403 then raise Unauthorized, "JAIT rejected token (#{res.code})"
    when 404 then raise NotFound, "JAIT 404 for #{path}"
    else raise Error, "JAIT #{res.code} for #{path}"
    end
  end
end
