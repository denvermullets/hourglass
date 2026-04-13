class Onboarding::CreateAccountService < Service
  def initialize(params:)
    @params = params
  end

  def call
    User.create!(
      username: @params[:username],
      email_address: @params[:email_address],
      password: @params[:password],
      password_confirmation: @params[:password_confirmation],
      onboarding_step: 2
    )
  end
end
