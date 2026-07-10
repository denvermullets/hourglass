require 'nokogiri'

class Jait::HighlightService < Service
  SKIP_ANCESTORS = %w[a code pre turbo-frame].freeze

  def initialize(html:, server: nil)
    @html = html.to_s
    @server = server
    @integration = server&.jait_integration
  end

  def call
    return @html if @html.blank? || @integration.nil? || !@integration.configured?

    fragment = Nokogiri::HTML5.fragment(@html)
    rewrite_anchor_urls(fragment)
    rewrite_bare_identifiers(fragment) if @integration.team_identifiers.any?
    fragment.to_html.html_safe
  end

  private

  def rewrite_anchor_urls(fragment)
    fragment.css('a[href]').each do |a|
      href = a['href'].to_s
      match = url_regex.match(href)
      next unless match

      team_id = match[:team_id].to_i
      next unless @integration.team_for(team_id)

      kind = match[:kind]
      id = match[:id]
      replacement_html = build_frame(team_id: team_id, kind: kind, id: id, fallback: a.to_html)
      a.replace(replacement_html)
    end
  end

  def rewrite_bare_identifiers(fragment)
    idents = @integration.team_identifiers.map { |i| Regexp.escape(i) }.join('|')
    pattern = /\b(?<ident>#{idents})-\d+\b/

    fragment.traverse do |node|
      next unless node.text?
      next if node.ancestors.map(&:name).intersect?(SKIP_ANCESTORS)
      next unless node.content =~ pattern

      build_text_replacement(node, pattern)
    end
  end

  def build_text_replacement(text_node, pattern)
    content = text_node.content
    parts = []
    last = 0
    content.scan(pattern) do
      m = Regexp.last_match
      parts << escape(content[last...m.begin(0)]) if m.begin(0) > last
      parts << render_identifier_match(m)
      last = m.end(0)
    end
    parts << escape(content[last..]) if last < content.length
    text_node.replace(Nokogiri::HTML5.fragment(parts.join))
  end

  def render_identifier_match(match)
    identifier = match[0]
    team = @integration.team_by_identifier(match[:ident])
    return escape(identifier) unless team

    build_frame(team_id: team['id'], kind: 'issue', identifier: identifier, fallback: escape(identifier))
  end

  def build_frame(team_id:, kind:, fallback:, id: nil, identifier: nil)
    singular = singularize_kind(kind)
    helpers = Rails.application.routes.url_helpers
    src, frame_id =
      if identifier
        [helpers.jait_card_by_identifier_path(server_id: @server.id, team_id: team_id, identifier: identifier),
         "jait-issue-ident-#{identifier}"]
      elsif id
        [helpers.jait_card_path(server_id: @server.id, team_id: team_id, kind: singular, id: id),
         "jait-#{singular}-#{team_id}-#{id}"]
      else
        [helpers.jait_card_path(server_id: @server.id, team_id: team_id, kind: singular),
         "jait-#{singular}-#{team_id}"]
      end
    %(<turbo-frame id="#{frame_id}" src="#{src}" loading="lazy" data-turbo-permanent>#{fallback}</turbo-frame>)
  end

  def singularize_kind(kind)
    case kind.to_s
    when 'issues' then 'issue'
    when 'projects' then 'project'
    when 'roadmap', 'roadmaps' then 'roadmap'
    else kind.to_s
    end
  end

  def url_regex
    @url_regex ||= begin
      base = Regexp.escape(@integration.base_url.to_s.chomp('/'))
      %r{\A#{base}/teams/(?<team_id>\d+)/(?<kind>issues|projects|roadmap)(?:/(?<id>\d+))?/?\z}
    end
  end

  def escape(str)
    ERB::Util.html_escape(str)
  end
end
