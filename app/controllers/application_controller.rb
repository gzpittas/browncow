class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_schedule_location, :current_schedule_record, :current_schedule_destination_for

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

    current_schedule = Schedule.current_for(location)
    return location_schedule_path(location, current_schedule) if current_schedule

    location_schedules_path(location)
  end

  def current_schedule_location
    return unless user_signed_in?
    return unless current_user.account.present?

    @current_schedule_location ||= current_user.account.locations.active.order(:name).first
  end

  def current_schedule_record
    return unless current_schedule_location

    @current_schedule_record ||= Schedule.current_for(current_schedule_location)
  end

  def current_schedule_destination_for(user = current_user, view: nil)
    return new_account_path if user.account.blank?

    location = user.account.locations.active.order(:name).first
    return dashboard_path if location.blank?

    schedule = Schedule.current_for(location)
    return location_schedule_path(location, schedule, view: view.presence) if schedule

    location_schedules_path(location)
  end
end
