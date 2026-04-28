class ChangelogController < ApplicationController
  layout 'app'

  def show
    path = Rails.root.join('CHANGELOG.md')
    text = File.exist?(path) ? File.read(path) : ''
    @html = Changelog::RenderService.call(text)
  end
end
