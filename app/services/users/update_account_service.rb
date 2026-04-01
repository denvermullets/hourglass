class Users::UpdateAccountService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    @user.update!(email_address: @params[:email_address])
    @user
  end
end
