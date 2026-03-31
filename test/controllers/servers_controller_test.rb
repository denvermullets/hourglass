require 'test_helper'

class ServersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test 'index lists user servers' do
    get servers_path
    assert_response :success
  end

  test 'new renders form' do
    get new_server_path
    assert_response :success
  end

  test 'create creates server and redirects' do
    assert_difference 'Server.count' do
      post servers_path, params: { server: { name: 'New Server', description: 'Test' } }
    end
    assert_redirected_to server_path(Server.last)
  end

  test 'create with invalid params renders new' do
    assert_no_difference 'Server.count' do
      post servers_path, params: { server: { name: '' } }
    end
    assert_response :unprocessable_entity
  end

  test 'show requires membership' do
    other_server = servers(:two)
    get server_path(other_server)
    assert_redirected_to servers_path
  end

  test 'show renders for member' do
    get server_path(servers(:one))
    assert_response :success
  end

  test 'settings requires admin role' do
    sign_in_as(users(:two))
    get settings_server_path(servers(:one))
    assert_redirected_to server_path(servers(:one))
  end

  test 'settings renders for owner' do
    get settings_server_path(servers(:one))
    assert_response :success
  end

  test 'update updates server' do
    patch server_path(servers(:one)), params: { server: { name: 'Updated' } }
    assert_redirected_to settings_server_path(servers(:one))
    assert_equal 'Updated', servers(:one).reload.name
  end

  test 'destroy requires owner' do
    sign_in_as(users(:two))
    delete server_path(servers(:one))
    assert_redirected_to server_path(servers(:one))
  end

  test 'destroy deletes server' do
    assert_difference 'Server.count', -1 do
      delete server_path(servers(:one))
    end
    assert_redirected_to servers_path
  end
end
