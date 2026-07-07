require 'test_helper'

class MemberManagementTest < ActionDispatch::IntegrationTest
  test 'admin can view the members settings tab' do
    sign_in_as(users(:three)) # admin of server one
    get settings_members_server_path(servers(:one))
    assert_response :success
  end

  test 'plain member cannot view the members settings tab' do
    sign_in_as(users(:two)) # member of server one
    get settings_members_server_path(servers(:one))
    assert_redirected_to server_path(servers(:one))
  end

  test 'admin removes a member and their messages remain' do
    message = channels(:general).messages.create!(user: users(:two), body: 'keep me')
    sign_in_as(users(:one)) # owner

    assert_difference 'Membership.count', -1 do
      delete remove_member_server_path(servers(:one), users(:two))
    end
    assert_redirected_to settings_members_server_path(servers(:one))
    assert Message.exists?(message.id)
  end

  test 'admin cannot remove another admin' do
    sign_in_as(users(:three)) # admin
    assert_no_difference 'Membership.count' do
      delete remove_member_server_path(servers(:one), users(:four)) # also admin
    end
    assert_redirected_to settings_members_server_path(servers(:one))
  end
end
