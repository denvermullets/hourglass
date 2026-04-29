require 'test_helper'

class MtasksProjectCacheTest < ActiveSupport::TestCase
  test 'primary key is mtasks_project_id' do
    assert_equal 'mtasks_project_id', MtasksProjectCache.primary_key
  end

  test 'requires name' do
    cache = MtasksProjectCache.new(mtasks_project_id: 12_345)
    assert_not cache.valid?
    assert cache.errors[:name].any?
  end

  test 'finds by primary key' do
    cache = MtasksProjectCache.find(mtasks_project_caches(:mtasks_integration).mtasks_project_id)
    assert_equal 'mtasks Integration', cache.name
  end
end
