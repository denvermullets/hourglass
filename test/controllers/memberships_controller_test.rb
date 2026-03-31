require 'test_helper'

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test 'create joins server with valid invite code' do
    server = servers(:two)
    assert_difference 'Membership.count' do
      post join_server_path, params: { invite_code: server.invite_code }
    end
    assert_redirected_to server_path(server)
  end

  test 'create rejects invalid invite code' do
    assert_no_difference 'Membership.count' do
      post join_server_path, params: { invite_code: 'badcode1' }
    end
    assert_redirected_to servers_path
  end

  test 'create rejects already member' do
    assert_no_difference 'Membership.count' do
      post join_server_path, params: { invite_code: servers(:one).invite_code }
    end
    assert_redirected_to servers_path
  end

  test 'destroy leaves server' do
    sign_in_as(users(:two))
    assert_difference 'Membership.count', -1 do
      delete server_membership_path(servers(:one))
    end
    assert_redirected_to servers_path
  end

  test 'destroy prevents owner from leaving' do
    assert_no_difference 'Membership.count' do
      delete server_membership_path(servers(:one))
    end
    assert_redirected_to server_path(servers(:one))
  end
end
