require 'nokogiri'

module Html
  # Shared helper for services that rewrite plain-text tokens (e.g. @mentions,
  # #channels) inside rendered HTML. Walks TEXT NODES only, never descending into
  # <a>/<code>/<pre>/<turbo-frame>, so tokens inside links or code blocks are left alone.
  module TextNodeRewriter
    SKIP_ANCESTORS = %w[a code pre turbo-frame].freeze

    private

    # Unique, downcased capture-group-1 tokens found in eligible text nodes of `html`.
    # Used to batch-resolve records in a single query before rewriting (avoids N+1).
    def tokens_in(html, pattern)
      eligible_text_nodes(Nokogiri::HTML5.fragment(html.to_s), pattern)
        .flat_map { |node| node.content.scan(pattern).map { |captures| captures.first.downcase } }
        .uniq
    end

    # Replace every `pattern` match in eligible text nodes with the block's return value
    # (an HTML string), or leave the matched text as escaped plain text when the block
    # returns nil. Collect-then-replace so we never re-descend into inserted markup and
    # re-match our own output.
    def rewrite_text_nodes(html, pattern, &)
      fragment = Nokogiri::HTML5.fragment(html.to_s)
      nodes = eligible_text_nodes(fragment, pattern)
      return html.html_safe if nodes.empty?

      nodes.each { |node| replace_node(node, pattern, &) }
      fragment.to_html.html_safe
    end

    def eligible_text_nodes(fragment, pattern)
      nodes = []
      fragment.traverse do |node|
        next unless node.text?
        next if node.ancestors.map(&:name).intersect?(SKIP_ANCESTORS)
        next unless node.content.match?(pattern)

        nodes << node
      end
      nodes
    end

    def replace_node(text_node, pattern)
      content = text_node.content
      parts = []
      last = 0
      content.scan(pattern) do
        match = Regexp.last_match
        parts << escape(content[last...match.begin(0)]) if match.begin(0) > last
        parts << (yield(match) || escape(match[0]))
        last = match.end(0)
      end
      parts << escape(content[last..]) if last < content.length
      text_node.replace(Nokogiri::HTML5.fragment(parts.join))
    end

    def escape(str)
      ERB::Util.html_escape(str)
    end
  end
end
