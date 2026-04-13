class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    redirect_to new_onboarding_credentials_path
  end

  def create
    redirect_to new_onboarding_credentials_path
  end
end
