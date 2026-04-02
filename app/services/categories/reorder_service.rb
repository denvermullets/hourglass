class Categories::ReorderService < Service
  def initialize(category:, direction:)
    @category = category
    @direction = direction
  end

  def call
    sibling = find_sibling
    return unless sibling

    ActiveRecord::Base.transaction do
      old_position = @category.position
      @category.update!(position: sibling.position)
      sibling.update!(position: old_position)
    end
  end

  private

  def find_sibling
    scope = @category.server.all_categories
    if @direction == :up
      scope.where('position < ?', @category.position).order(position: :desc).first
    else
      scope.where('position > ?', @category.position).order(position: :asc).first
    end
  end
end
