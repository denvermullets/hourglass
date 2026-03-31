class Categories::UpdateService < Service
  def initialize(category:, params:)
    @category = category
    @params = params
  end

  def call
    @category.update!(@params)
    @category
  end
end
