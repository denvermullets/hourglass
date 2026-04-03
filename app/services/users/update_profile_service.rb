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

    attrs = { display_name: @params[:display_name], bio: @params[:bio] }
    attrs[:username] = @params[:username] if @params[:username].present?

    @user.update!(attrs)
    @user
  end
end
