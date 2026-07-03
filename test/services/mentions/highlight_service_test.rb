require 'test_helper'

module Mentions
  class HighlightServiceTest < ActiveSupport::TestCase
    setup do
      @userone = users(:one)   # username: userone
      @usertwo = users(:two)   # username: usertwo
      @scope = servers(:one).users # both userone and usertwo are members
    end

    # --- markdown mode ---

    test 'resolves an @username in scope into a mention span' do
      html = Mentions::HighlightService.call(
        html: 'hey @usertwo', current_user: @userone, scope: @scope, markdown: true
      )

      assert_includes html, '<span class="mention" data-mention-username="usertwo">@usertwo</span>'
    end

    test 'marks the viewer\'s own mention as mention-self' do
      html = Mentions::HighlightService.call(
        html: 'hey @usertwo', current_user: @usertwo, scope: @scope, markdown: true
      )

      assert_includes html, 'class="mention mention-self"'
    end

    test 'leaves an @username that is not in scope as plain text' do
      html = Mentions::HighlightService.call(
        html: 'hey @userone', current_user: @usertwo,
        scope: User.where(id: @usertwo.id), markdown: true
      )

      assert_includes html, '@userone'
      refute_includes html, '<span class="mention"'
    end

    test 'leaves an unknown @username as plain text' do
      html = Mentions::HighlightService.call(
        html: 'hey @ghost', current_user: @userone, scope: @scope, markdown: true
      )

      assert_includes html, '@ghost'
      refute_includes html, 'class="mention"'
    end

    test 'does not match inside code, pre, or anchor elements' do
      html = Mentions::HighlightService.call(
        html: '<code>@usertwo</code> <pre>@usertwo</pre> <a href="/x">@usertwo</a>',
        current_user: @userone, scope: @scope, markdown: true
      )

      refute_includes html, 'class="mention"'
      assert_includes html, '<code>@usertwo</code>'
    end

    test 'does not match an email local part' do
      html = Mentions::HighlightService.call(
        html: 'mail a@usertwo.com now', current_user: @userone, scope: @scope, markdown: true
      )

      refute_includes html, 'class="mention"'
      assert_includes html, 'a@usertwo.com'
    end

    test 'returns blank input unchanged' do
      assert_equal '', Mentions::HighlightService.call(html: '', scope: @scope, markdown: true)
    end

    # --- legacy span mode ---

    test 'still rewrites editor-mention spans in legacy mode' do
      html = Mentions::HighlightService.call(
        html: '<span class="editor-mention" data-mention-username="usertwo">@usertwo</span>',
        current_user: @userone
      )

      assert_includes html, 'class="mention"'
      assert_includes html, 'data-mention-username="usertwo"'
    end
  end
end
