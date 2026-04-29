require 'test_helper'

class MtasksLinkTest < ActiveSupport::TestCase
  def base_attrs
    {
      server_integration: server_integrations(:jait_one),
      mtasks_team_id: 21,
      created_by_user: users(:one)
    }
  end

  test 'project_channel link is valid with channel + project ids' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'project_channel',
                            channel: channels(:general),
                            mtasks_project_id: 2002
                          ))
    assert link.valid?, link.errors.full_messages.inspect
  end

  test 'project_channel link rejects thread_id' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'project_channel',
                            channel: channels(:general),
                            mtasks_project_id: 2002,
                            thread: messages(:one)
                          ))
    assert_not link.valid?
    assert link.errors[:thread_id].any?
  end

  test 'project_channel link rejects mtasks_issue_id' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'project_channel',
                            channel: channels(:general),
                            mtasks_project_id: 2002,
                            mtasks_issue_id: 5
                          ))
    assert_not link.valid?
    assert link.errors[:mtasks_issue_id].any?
  end

  test 'project_channel link requires channel and project' do
    link = MtasksLink.new(base_attrs.merge(link_type: 'project_channel'))
    assert_not link.valid?
    assert link.errors[:channel_id].any?
    assert link.errors[:mtasks_project_id].any?
  end

  test 'issue_thread link is valid with thread + issue ids' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'issue_thread',
                            thread: messages(:one),
                            mtasks_issue_id: 7777,
                            mtasks_issue_identifier: 'HOUR-7777'
                          ))
    assert link.valid?, link.errors.full_messages.inspect
  end

  test 'issue_thread link rejects channel_id' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'issue_thread',
                            thread: messages(:one),
                            mtasks_issue_id: 7777,
                            channel: channels(:general)
                          ))
    assert_not link.valid?
    assert link.errors[:channel_id].any?
  end

  test 'issue_thread link rejects mtasks_project_id' do
    link = MtasksLink.new(base_attrs.merge(
                            link_type: 'issue_thread',
                            thread: messages(:one),
                            mtasks_issue_id: 7777,
                            mtasks_project_id: 9
                          ))
    assert_not link.valid?
    assert link.errors[:mtasks_project_id].any?
  end

  test 'rejects unknown link_type' do
    link = MtasksLink.new(base_attrs.merge(link_type: 'bogus'))
    assert_not link.valid?
    assert link.errors[:link_type].any?
  end

  test 'partial unique index rejects duplicate channel for project_channel' do
    MtasksLink.create!(base_attrs.merge(
                         link_type: 'project_channel',
                         channel: channels(:general),
                         mtasks_project_id: 3003
                       ))
    assert_raises(ActiveRecord::RecordNotUnique) do
      MtasksLink.create!(base_attrs.merge(
                           link_type: 'project_channel',
                           channel: channels(:general),
                           mtasks_project_id: 3004
                         ))
    end
  end

  test 'partial unique index rejects duplicate project for project_channel' do
    MtasksLink.create!(base_attrs.merge(
                         link_type: 'project_channel',
                         channel: channels(:general),
                         mtasks_project_id: 4004
                       ))
    other_channel = Channel.create!(server: servers(:one), name: 'other-channel')
    assert_raises(ActiveRecord::RecordNotUnique) do
      MtasksLink.create!(base_attrs.merge(
                           link_type: 'project_channel',
                           channel: other_channel,
                           mtasks_project_id: 4004
                         ))
    end
  end

  test 'partial unique index rejects duplicate thread for issue_thread' do
    MtasksLink.create!(base_attrs.merge(
                         link_type: 'issue_thread',
                         thread: messages(:one),
                         mtasks_issue_id: 5005
                       ))
    assert_raises(ActiveRecord::RecordNotUnique) do
      MtasksLink.create!(base_attrs.merge(
                           link_type: 'issue_thread',
                           thread: messages(:one),
                           mtasks_issue_id: 5006
                         ))
    end
  end

  test 'project_channel and issue_thread on same channel/thread coexist via partial index' do
    project_link = MtasksLink.create!(base_attrs.merge(
                                        link_type: 'project_channel',
                                        channel: channels(:general),
                                        mtasks_project_id: 6006
                                      ))
    issue_link = MtasksLink.create!(base_attrs.merge(
                                      link_type: 'issue_thread',
                                      thread: messages(:one),
                                      mtasks_issue_id: 6007
                                    ))
    assert project_link.persisted?
    assert issue_link.persisted?
  end
end
