module Onboarding
  class BaseController < ApplicationController
    layout 'auth'
    skip_before_action :redirect_if_onboarding_incomplete!

    private

    def ensure_onboarding_step!(max_step)
      return unless Current.session
      return if Current.user.onboarding_complete?
      return if Current.user.onboarding_step <= max_step

      redirect_to Current.user.current_onboarding_path
    end
  end
end
