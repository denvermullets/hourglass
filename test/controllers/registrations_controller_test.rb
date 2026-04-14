require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test 'new redirects to onboarding credentials' do
    get new_registration_path
    assert_redirected_to new_onboarding_credentials_path
  end

  test 'create redirects to onboarding credentials' do
    post registration_path, params: {
      user: {
        username: 'newuser',
        email_address: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    }

    assert_redirected_to new_onboarding_credentials_path
  end
end
