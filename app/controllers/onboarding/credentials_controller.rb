module Onboarding
  class CredentialsController < BaseController
    allow_unauthenticated_access
    rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
      redirect_to new_onboarding_credentials_path, alert: 'Try again later.'
    }

    def new
      if authenticated? && !Current.user.onboarding_complete?
        redirect_to Current.user.current_onboarding_path
        return
      end

      @user = User.new
    end

    def create
      user = Onboarding::CreateAccountService.call(params: credential_params)
      start_new_session_for(user)
      redirect_to onboarding_profile_path
    rescue ActiveRecord::RecordInvalid => e
      @user = e.record.is_a?(User) ? e.record : User.new(credential_params.except(:password, :password_confirmation))
      render :new, status: :unprocessable_entity
    end

    private

    def credential_params
      params.require(:user).permit(:username, :email_address, :password, :password_confirmation)
    end
  end
end
