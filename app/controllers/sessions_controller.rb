class SessionsController < ApplicationController
  layout 'auth'
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_session_path, alert: 'Try again later.'
  }

  def new; end

  def create
    login = params[:login].to_s.strip
    user = if login.include?('@')
             User.find_by(email_address: login.downcase)
           else
             User.find_by(username: login.downcase)
           end

    if user&.authenticate(params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      flash.now[:alert] = 'Invalid username/email or password.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
