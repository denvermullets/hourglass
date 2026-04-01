class Users::UpdatePasswordService < Service
  class InvalidPassword < StandardError; end

  def initialize(user:, current_password:, new_password:, new_password_confirmation:)
    @user = user
    @current_password = current_password
    @new_password = new_password
    @new_password_confirmation = new_password_confirmation
  end

  def call
    raise InvalidPassword, 'Current password is incorrect' unless @user.authenticate(@current_password)
    raise InvalidPassword, 'New passwords do not match' unless @new_password == @new_password_confirmation
    raise InvalidPassword, 'New password must be at least 8 characters' if @new_password.length < 8

    @user.update!(password: @new_password)
    @user
  end
end
