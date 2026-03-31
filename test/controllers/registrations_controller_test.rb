require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_registration_path
    assert_response :success
  end

  test 'create with valid params' do
    assert_difference('User.count', 1) do
      post registration_path, params: {
        user: {
          username: 'newuser',
          email_address: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test 'create with invalid params' do
    assert_no_difference('User.count') do
      post registration_path, params: {
        user: {
          username: '',
          email_address: 'bad',
          password: 'short',
          password_confirmation: 'short'
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test 'create with duplicate username' do
    existing = users(:one)

    assert_no_difference('User.count') do
      post registration_path, params: {
        user: {
          username: existing.username,
          email_address: 'unique@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
