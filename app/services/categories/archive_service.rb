class Categories::ArchiveService < Service
  def initialize(category:)
    @category = category
  end

  def call
    ActiveRecord::Base.transaction do
      @category.archive!
      @category.channels.each(&:archive!)
    end
    Sidebar::BroadcastService.call(server: @category.server, action: :replace_all_categories)
  end
end
