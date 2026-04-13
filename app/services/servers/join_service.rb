class Servers::JoinService < Service
  class AlreadyMemberError < StandardError; end

  def initialize(user:, invite_code:)
    @user = user
    @invite_code = invite_code
  end

  def call
    server = Server.find_by!(invite_code: @invite_code)

    raise AlreadyMemberError, 'You are already a member of this server.' if server.membership_for(@user)

    server.memberships.create!(user: @user, role: :member)
    Servers::AnnounceJoinService.call(server: server, user: @user)
    server
  end
end
