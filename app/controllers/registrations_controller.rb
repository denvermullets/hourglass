class RegistrationsController < ApplicationController
  layout 'auth'
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_registration_path, alert: 'Try again later.'
  }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(
      :username, :email_address, :password, :password_confirmation,
      :display_name, :bio, favorite_artists: []
    )
  end
end
