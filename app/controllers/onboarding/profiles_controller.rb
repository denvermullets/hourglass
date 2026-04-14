module Onboarding
  class ProfilesController < BaseController
    before_action :ensure_onboarding_step!

    def show
      @user = Current.user
    end

    def update
      if params[:skip].present?
        Current.user.update!(onboarding_step: 3)
        redirect_to onboarding_channels_path
        return
      end

      Onboarding::UpdateProfileService.call(user: Current.user, params: profile_params)
      redirect_to onboarding_channels_path
    rescue ActiveRecord::RecordInvalid
      @user = Current.user
      render :show, status: :unprocessable_entity
    end

    private

    def ensure_onboarding_step!
      super(2)
    end

    def profile_params
      params.require(:user).permit(:display_name, :bio, :avatar)
    end
  end
end
