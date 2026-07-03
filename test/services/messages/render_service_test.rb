require 'test_helper'

module Messages
  class RenderServiceTest < ActiveSupport::TestCase
    test 'renders a fenced code block with a language, syntax-highlighted, surviving sanitize' do
      markdown = "```ruby\ndef foo\n  1\nend\n```"

      html = Messages::RenderService.call(markdown: markdown)

      assert_includes html, 'editor-code-block'
      assert_includes html, 'highlight'
      assert_includes html, 'data-highlight-language="ruby"'
      # Rouge token spans (e.g. class="k" for the `def` keyword) prove highlighting
      # ran after sanitize and its classes were not stripped.
      assert_match(/<span class="[a-z0-9]+">/, html)
    end

    test 'renders a fenced code block without a language (lexer is guessed)' do
      markdown = "```\nputs 'hi'\n```"

      html = Messages::RenderService.call(markdown: markdown)

      assert_includes html, 'editor-code-block'
    end

    test 'renders inline markdown formatting' do
      html = Messages::RenderService.call(markdown: '**bold** and _italic_ with `code`')

      assert_includes html, '<strong>bold</strong>'
      assert_includes html, '<em>italic</em>'
      assert_includes html, '<code>code</code>'
    end

    test 'strips unsafe raw HTML tags (inert text may remain)' do
      html = Messages::RenderService.call(markdown: 'hello <script>alert(1)</script> world')

      refute_includes html, '<script'
      refute_includes html, '</script>'
    end

    test 'returns an empty string for blank input' do
      assert_equal '', Messages::RenderService.call(markdown: '')
      assert_equal '', Messages::RenderService.call(markdown: nil)
    end
  end
end
