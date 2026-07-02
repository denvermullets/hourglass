class ApplicationController < ActionController::Base
  include Authentication

  before_action :redirect_if_onboarding_incomplete!
  before_action :touch_last_seen

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # DB-backed presence: mark the current user "seen" on any request (poll or navigation).
  # Throttled so we write at most ~once per 20s per active user, well inside the 45s
  # online window used by Server#online_count.
  def touch_last_seen
    user = Current.user
    return unless user
    return if user.last_seen_at && user.last_seen_at > 20.seconds.ago

    user.update_column(:last_seen_at, Time.current)
  end
end
