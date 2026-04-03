class SettingsController < ApplicationController
  layout 'app'

  def show
    redirect_to profile_settings_path
  end

  def profile
    render_tab('profile', 'settings/profile_content', { user: Current.user })
  end

  def account
    render_tab('account', 'settings/account_content', { user: Current.user })
  end

  def notifications
    render_tab('notifications', 'settings/notifications_content', {
                 user: Current.user,
                 channel_memberships: Current.user.channel_memberships.includes(channel: :server)
               })
  end

  def appearance
    render_tab('appearance', 'settings/appearance_content', { user: Current.user })
  end

  def update_profile
    Users::UpdateProfileService.call(user: Current.user, params: profile_params)
    redirect_to profile_settings_path, notice: 'Profile updated.', status: :see_other
  rescue ActiveRecord::RecordInvalid
    render_tab('profile', 'settings/profile_content', { user: Current.user }, status: :unprocessable_entity)
  end

  def update_account
    Users::UpdateAccountService.call(user: Current.user, params: account_params)
    redirect_to account_settings_path, notice: 'Account updated.', status: :see_other
  rescue ActiveRecord::RecordInvalid
    render_tab('account', 'settings/account_content', { user: Current.user }, status: :unprocessable_entity)
  end

  def update_password
    Users::UpdatePasswordService.call(
      user: Current.user,
      current_password: params[:current_password],
      new_password: params[:new_password],
      new_password_confirmation: params[:new_password_confirmation]
    )
    redirect_to account_settings_path, notice: 'Password updated.', status: :see_other
  rescue Users::UpdatePasswordService::InvalidPassword => e
    redirect_to account_settings_path, alert: e.message, status: :see_other
  end

  def update_notifications
    Users::UpdateNotificationsService.call(
      user: Current.user,
      notification_params: notification_params,
      muted_channel_ids: params[:muted_channel_ids] || []
    )
    redirect_to notifications_settings_path, notice: 'Notification preferences saved.', status: :see_other
  end

  def update_appearance
    Users::UpdateAppearanceService.call(user: Current.user, params: appearance_params)
    flash[:notice] = 'Appearance updated.'
    redirect_to appearance_settings_path, status: :see_other
  end

  private

  def render_tab(tab, partial, locals, status: :ok)
    if turbo_frame_request?
      render partial: 'settings/tabs_and_panel',
             locals: { tab: tab, panel_partial: partial, panel_locals: locals },
             status: status
    else
      @tab = tab
      @panel_partial = partial
      @panel_locals = locals
      render :show, status: status
    end
  end

  def profile_params
    params.permit(:username, :display_name, :bio, :avatar, :remove_avatar)
  end

  def account_params
    params.permit(:email_address)
  end

  def notification_params
    params.permit(:direct_messages, :mentions, :thread_replies, :reactions, :email_digest)
  end

  def appearance_params
    params.permit(:theme, :timestamp_format, :timezone, :sidebar_position, :text_size, :text_size_mobile)
  end
end
