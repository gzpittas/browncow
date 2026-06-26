class ApplicationController < ActionController::Base
  SCHEDULE_SECTION_MODES = %w[foh boh all].freeze
  SCHEDULE_VIEW_MODES = %w[positions employees both].freeze

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_schedule_location, :current_schedule_record, :current_schedule_destination_for, :current_schedule_section_mode, :current_schedule_view_mode

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

    remembered_schedule = remembered_schedule_for(user)
    return location_schedule_path(remembered_schedule.location, remembered_schedule, view: current_schedule_view_mode, section: current_schedule_section_mode) if remembered_schedule

    location = user.account.locations.active.order(:name).first
    return dashboard_path if location.blank?

    current_schedule = Schedule.current_for(location)
    return location_schedule_path(location, current_schedule, view: current_schedule_view_mode, section: current_schedule_section_mode) if current_schedule

    location_schedules_path(location)
  end

  def current_schedule_location
    return unless user_signed_in?
    return unless current_user.account.present?

    @current_schedule_location ||= current_schedule_record&.location || current_user.account.locations.active.order(:name).first
  end

  def current_schedule_record
    return unless user_signed_in?
    return unless current_user.account.present?

    @current_schedule_record ||= remembered_schedule_for(current_user) || Schedule.current_for(current_user.account.locations.active.order(:name).first)
  end

  def current_schedule_destination_for(user = current_user, view: nil, section: nil)
    return new_account_path if user.account.blank?

    remembered_schedule = remembered_schedule_for(user)
    selected_view = normalized_schedule_view_mode(view.presence || current_schedule_view_mode)
    selected_section = normalized_schedule_section_mode(section) || current_schedule_section_mode

    return location_schedule_path(remembered_schedule.location, remembered_schedule, view: selected_view, section: selected_section) if remembered_schedule

    location = user.account.locations.active.order(:name).first
    return dashboard_path if location.blank?

    schedule = Schedule.current_for(location)
    return location_schedule_path(location, schedule, view: selected_view, section: selected_section) if schedule

    location_schedules_path(location)
  end

  def current_schedule_section_mode
    normalized_schedule_section_mode(session[:schedule_section_mode]) || "foh"
  end

  def current_schedule_view_mode
    normalized_schedule_view_mode(session[:schedule_view_mode])
  end

  def store_schedule_section_mode!(value)
    normalized_value = normalized_schedule_section_mode(value) || "foh"
    session[:schedule_section_mode] = normalized_value
    normalized_value
  end

  def store_schedule_view_mode!(value)
    normalized_value = normalized_schedule_view_mode(value)
    session[:schedule_view_mode] = normalized_value
    normalized_value
  end

  def remember_schedule_context!(location:, schedule:, view:, section:)
    session[:current_schedule_location_id] = location.id
    session[:current_schedule_id] = schedule.id
    store_schedule_view_mode!(view)
    store_schedule_section_mode!(section)
  end

  def normalized_schedule_section_mode(value)
    normalized_value = value.to_s
    return normalized_value if SCHEDULE_SECTION_MODES.include?(normalized_value)

    nil
  end

  def normalized_schedule_view_mode(value)
    normalized_value = value.to_s
    return normalized_value if SCHEDULE_VIEW_MODES.include?(normalized_value)

    "positions"
  end

  def remembered_schedule_for(user)
    return unless user&.account.present?

    location_id = session[:current_schedule_location_id]
    schedule_id = session[:current_schedule_id]
    return if location_id.blank? || schedule_id.blank?

    location = user.account.locations.active.find_by(id: location_id)
    return clear_remembered_schedule_context! unless location

    location.schedules.find_by(id: schedule_id) || clear_remembered_schedule_context!
  end

  def clear_remembered_schedule_context!
    session.delete(:current_schedule_location_id)
    session.delete(:current_schedule_id)
    nil
  end
end
