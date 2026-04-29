require 'test_helper'

class MtasksIssueCacheTest < ActiveSupport::TestCase
  test 'primary key is mtasks_issue_id' do
    assert_equal 'mtasks_issue_id', MtasksIssueCache.primary_key
  end

  test 'requires identifier' do
    cache = MtasksIssueCache.new(mtasks_issue_id: 12_345)
    assert_not cache.valid?
    assert cache.errors[:identifier].any?
  end

  test 'active scope excludes soft-deleted' do
    active = MtasksIssueCache.active
    assert active.exists?(mtasks_issue_id: mtasks_issue_caches(:hour51).mtasks_issue_id)
    assert_not active.exists?(mtasks_issue_id: mtasks_issue_caches(:deletedone).mtasks_issue_id)
  end

  test 'deleted? reflects deleted_at' do
    assert mtasks_issue_caches(:deletedone).deleted?
    assert_not mtasks_issue_caches(:hour51).deleted?
  end
end
