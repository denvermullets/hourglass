class Categories::ArchiveService < Service
  def initialize(category:)
    @category = category
  end

  def call
    ActiveRecord::Base.transaction do
      @category.archive!
      @category.channels.each(&:archive!)
    end
  end
end
