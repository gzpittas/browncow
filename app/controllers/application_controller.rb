class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  def after_sign_in_path_for(resource)
    signed_in_landing_path_for(resource)
  end

  def after_sign_up_path_for(resource)
    signed_in_landing_path_for(resource)
  end

  def require_account!
    return if current_user.account.present?

    redirect_to new_account_path, alert: "Set up your restaurant account to continue."
  end

  def signed_in_landing_path_for(user)
    return new_account_path if user.account.blank?

    location = user.account.locations.active.order(:name).first
    return dashboard_path if location.blank?

    current_schedule = location.schedules.find_by(week_start_date: Schedule.week_start_for(Date.current))
    return location_schedule_path(location, current_schedule) if current_schedule

    location_schedules_path(location)
  end
end
