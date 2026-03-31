class Servers::LeaveService < Service
  class OwnerCannotLeaveError < StandardError; end

  def initialize(user:, server:)
    @user = user
    @server = server
  end

  def call
    membership = @server.membership_for(@user)
    raise ActiveRecord::RecordNotFound, 'Not a member' unless membership
    raise OwnerCannotLeaveError, 'Server owners cannot leave. Transfer ownership first.' if membership.owner?

    membership.destroy!
  end
end
