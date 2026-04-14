module Onboarding
  class ChannelsController < BaseController
    before_action :ensure_onboarding_step!

    def show; end

    def update
      join_server_or_create
    rescue ActiveRecord::RecordNotFound
      flash.now[:alert] = 'Invalid invite code.'
      render :show, status: :unprocessable_entity
    rescue Servers::JoinService::AlreadyMemberError => e
      flash.now[:alert] = e.message
      render :show, status: :unprocessable_entity
    end

    private

    def ensure_onboarding_step!
      super(3)
    end

    def join_server_or_create
      Current.user.update!(onboarding_step: 0)

      if params[:invite_code].present?
        server = Servers::JoinService.call(user: Current.user, invite_code: params[:invite_code])
        redirect_to server_path(server)
      else
        redirect_to new_server_path
      end
    end
  end
end
