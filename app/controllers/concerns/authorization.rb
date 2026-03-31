module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership
  end

  private

  def current_membership
    @current_membership ||= @server&.membership_for(Current.user)
  end

  def require_membership!
    return if current_membership

    redirect_to servers_path, alert: 'You are not a member of this server.'
  end

  def require_role!(role)
    require_membership!
    return if performed?

    return if current_membership.at_least?(role)

    redirect_to server_path(@server), alert: "You don't have permission to do that."
  end

  def require_moderator!
    require_role!(:moderator)
  end

  def require_admin!
    require_role!(:admin)
  end

  def require_owner!
    require_role!(:owner)
  end
end
