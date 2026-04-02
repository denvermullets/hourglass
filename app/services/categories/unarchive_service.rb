class Categories::UnarchiveService < Service
  def initialize(category:)
    @category = category
  end

  def call
    ActiveRecord::Base.transaction do
      @category.unarchive!
      @category.channels.each(&:unarchive!)
    end
  end
end
