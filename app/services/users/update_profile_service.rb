class Users::UpdateProfileService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    if @params[:remove_avatar] == '1'
      @user.avatar.purge
    elsif @params[:avatar].present?
      @user.avatar.attach(@params[:avatar])
    end

    @user.update!(
      display_name: @params[:display_name],
      bio: @params[:bio]
    )
    @user
  end
end
