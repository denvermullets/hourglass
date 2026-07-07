class Servers::RemoveMemberService < Service
  class CannotRemoveOwnerError < StandardError; end
  class InsufficientRoleError < StandardError; end

  def initialize(server:, actor:, target_user:)
    @server = server
    @actor = actor
    @target_user = target_user
  end

  def call
    membership = @server.membership_for(@target_user)
    raise ActiveRecord::RecordNotFound, 'Not a member' unless membership
    raise CannotRemoveOwnerError, 'The server owner cannot be removed.' if membership.owner?

    actor_membership = @server.membership_for(@actor)
    unless actor_membership && outranks?(actor_membership, membership)
      raise InsufficientRoleError, 'You can only remove members with a lower role than yours.'
    end

    ActiveRecord::Base.transaction do
      # Membership deletion does not cascade to channel_memberships, so clear the
      # target's per-channel read state for this server. Messages belong to the
      # user (not the membership) and are intentionally left untouched.
      ChannelMembership.where(user: @target_user, channel: @server.channels).delete_all
      membership.destroy!
    end
  end

  private

  def outranks?(actor_membership, target_membership)
    Membership.roles[actor_membership.role] < Membership.roles[target_membership.role]
  end
end
