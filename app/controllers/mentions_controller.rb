class MentionsController < ApplicationController
  def search
    channel = Channel.find_by(id: params[:channel_id])
    return render(json: []) if channel.nil?

    membership = channel.server.memberships.find_by(user_id: Current.user.id)
    return render(json: []) if membership.nil?

    results = Mentions::SearchService.call(
      channel: channel, query: params[:q], current_user: Current.user
    )
    render json: results.map { |row| row.except(:hourglass_user_id) }
  end
end
