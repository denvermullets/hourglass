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

  def fetch_projects(team_id)
    res = get("/api/v1/teams/#{team_id}/projects")
    res.is_a?(Hash) && res['projects'] ? res['projects'] : Array(res)
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

  def create_issue(team_id:, project_id:, title:, creator:)
    post("/api/v1/teams/#{team_id}/projects/#{project_id}/issues",
         body: { title: title, creator_email: creator })
  end

  def update_issue_status(team_id:, issue_id:, status:)
    patch("/api/v1/teams/#{team_id}/issues/#{issue_id}", body: { status: status })
  end

  # TODO: POST to a notifications endpoint once mtasks defines one. Stubbed
  # so the outbound emitter has a stable surface to call.
  def notify_user(mtasks_user_id:, body:, source_message_id:, idempotency_key:)
    Rails.logger.info(
      "[Jait] notify_user TODO mtasks_user_id=#{mtasks_user_id} " \
      "message=#{source_message_id} idempotency=#{idempotency_key} body=#{body.to_s.truncate(80)}"
    )
    nil
  end

  def post_issue_comment(team_id:, issue_id:, body:, idempotency_key:)
    post("/api/v1/teams/#{team_id}/issues/#{issue_id}/comments",
         body: { body: body },
         headers: { 'Idempotency-Key' => idempotency_key.to_s })
  end

  def post_project_comment(team_id:, project_id:, body:, idempotency_key:)
    post("/api/v1/teams/#{team_id}/projects/#{project_id}/comments",
         body: { body: body },
         headers: { 'Idempotency-Key' => idempotency_key.to_s })
  end

  def update_comment(team_id:, comment_id:, body:)
    put("/api/v1/teams/#{team_id}/comments/#{comment_id}", body: { body: body })
  end

  def delete_comment(team_id:, comment_id:)
    delete("/api/v1/teams/#{team_id}/comments/#{comment_id}")
  end

  def post_issue_decision(team_id:, issue_id:, decision:, idempotency_key:)
    post("/api/v1/teams/#{team_id}/issues/#{issue_id}/decisions",
         body: decision,
         headers: { 'Idempotency-Key' => idempotency_key.to_s })
  end

  def post_project_decision(team_id:, project_id:, decision:, idempotency_key:)
    post("/api/v1/teams/#{team_id}/projects/#{project_id}/decisions",
         body: decision,
         headers: { 'Idempotency-Key' => idempotency_key.to_s })
  end

  def delete_issue_decision(team_id:, issue_id:, decision_id:)
    delete("/api/v1/teams/#{team_id}/issues/#{issue_id}/decisions/#{decision_id}")
  end

  def delete_project_decision(team_id:, project_id:, decision_id:)
    delete("/api/v1/teams/#{team_id}/projects/#{project_id}/decisions/#{decision_id}")
  end

  private

  attr_reader :integration

  def get(path)
    request(:get, path)
  end

  def post(path, body:, headers: {})
    request(:post, path, body: body, headers: headers)
  end

  def put(path, body:)
    request(:put, path, body: body)
  end

  def patch(path, body:)
    request(:patch, path, body: body)
  end

  def delete(path)
    request(:delete, path)
  end

  def request(method, path, body: nil, headers: {})
    res = perform_request(method, path, body: body, headers: headers)
    handle_response(res, path)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise Error, "JAIT connection failed: #{e.message}"
  end

  def perform_request(method, path, body: nil, headers: {})
    uri = URI.join(integration.base_url.to_s, path)
    req = build_request(method, uri, body: body, headers: headers)
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == 'https',
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(req) }
  end

  def build_request(method, uri, body:, headers:)
    klass = {
      get: Net::HTTP::Get, post: Net::HTTP::Post,
      put: Net::HTTP::Put, patch: Net::HTTP::Patch,
      delete: Net::HTTP::Delete
    }.fetch(method)
    req = klass.new(uri)
    req['Authorization'] = "Bearer #{integration.api_token}"
    req['Accept'] = 'application/json'
    if body
      req['Content-Type'] = 'application/json'
      req.body = JSON.generate(body)
    end
    headers.each { |k, v| req[k] = v }
    req
  end

  def handle_response(res, path)
    case res.code.to_i
    when 200, 201 then JSON.parse(res.body)
    when 204 then nil
    when 401, 403 then raise Unauthorized, "JAIT rejected token (#{res.code})"
    when 404 then raise NotFound, "JAIT 404 for #{path}"
    else raise Error, "JAIT #{res.code} for #{path}"
    end
  end
end
