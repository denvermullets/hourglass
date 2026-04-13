class Onboarding::UpdateProfileService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    @user.avatar.attach(@params[:avatar]) if @params[:avatar].present?

    @user.update!(
      display_name: @params[:display_name],
      bio: @params[:bio],
      onboarding_step: 3
    )

    @user
  end
end
