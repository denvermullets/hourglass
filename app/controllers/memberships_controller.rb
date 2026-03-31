class MembershipsController < ApplicationController
  layout 'app'

  def create
    @server = Servers::JoinService.call(user: Current.user, invite_code: params[:invite_code])
    redirect_to server_path(@server), notice: "Joined #{@server.name}!"
  rescue ActiveRecord::RecordNotFound
    redirect_to servers_path, alert: 'Invalid invite code.'
  rescue Servers::JoinService::AlreadyMemberError => e
    redirect_to servers_path, alert: e.message
  end

  def destroy
    server = Server.find(params[:server_id])
    Servers::LeaveService.call(user: Current.user, server: server)
    redirect_to servers_path, notice: "Left #{server.name}."
  rescue Servers::LeaveService::OwnerCannotLeaveError
    redirect_to server_path(server), alert: 'Server owners cannot leave. Transfer ownership first.'
  end
end
