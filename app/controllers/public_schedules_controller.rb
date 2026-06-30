class PublicSchedulesController < ApplicationController
  layout "public_schedule"

  before_action :set_account
  before_action :ensure_public_schedule_enabled!
  before_action :set_location
  before_action :set_public_schedule_context, only: :show
  helper_method :public_schedule_params

  def show
    render :locked unless public_schedule_unlocked?
  end

  def unlock
    if @account.public_schedule_password_authenticated?(params[:password])
      session[public_schedule_session_key] = true
      redirect_to public_schedule_path(@account.public_schedule_slug)
    else
      flash.now[:alert] = "That password did not work."
      render :locked, status: :unauthorized
    end
  end

  private

  def set_account
    @account = Account.find_by!(public_schedule_slug: params[:account_slug])
  end

  def ensure_public_schedule_enabled!
    return if @account.public_schedule_enabled?

    raise ActiveRecord::RecordNotFound
  end

  def set_location
    @location = @account.locations.active.order(:name).first
    raise ActiveRecord::RecordNotFound if @location.blank?
  end

  def set_public_schedule_context
    @view_mode = normalized_schedule_view_mode(params[:view])
    @section_mode = normalized_schedule_section_mode(params[:section]) || "all"
    @available_schedules = public_available_schedules
    @schedule = selected_public_schedule
    return if @schedule.blank?

    @week_dates = @schedule.week_dates
    @positions = positions_for_section.includes(:employees).ordered
    @employees = employees_for_section
      .includes(:positions)
      .distinct
      .order(:first_name, :last_name)
    @shifts = shifts_for_section.includes(:position, employee: :positions).ordered
    @shifts_by_employee_and_date = @shifts.group_by { |shift| [ shift.employee_id, shift.shift_date ] }
    @shifts_by_position_and_date = @shifts.group_by { |shift| [ shift.position_id, shift.shift_date ] }
    @employees_by_position = @positions.index_with do |position|
      position.employees.select(&:active?).sort_by { |employee| [ employee.first_name.to_s.downcase, employee.last_name.to_s.downcase ] }
    end
    set_selected_employee_context
  end

  def set_selected_employee_context
    return if params[:employee_id].blank?

    @selected_employee = @location.employees.active.find_by(id: params[:employee_id])
    return if @selected_employee.blank?

    @selected_employee_shifts = @schedule.shifts
      .where(employee: @selected_employee)
      .includes(:position)
      .ordered
    @selected_employee_shifts_by_date = @selected_employee_shifts.group_by(&:shift_date)
  end

  def public_available_schedules
    current_week_start = Schedule.week_start_for(Date.current)
    week_starts = [ current_week_start, current_week_start + 1.week ]

    @location.schedules.published.where(week_start_date: week_starts).order(:week_start_date).to_a
  end

  def selected_public_schedule
    requested_schedule = @available_schedules.find { |schedule| schedule.id.to_s == params[:schedule_id].to_s }

    requested_schedule || @available_schedules.first
  end

  def positions_for_section
    scope = @location.positions.active
    return scope if @section_mode == "all"

    scope.where(section: @section_mode)
  end

  def employees_for_section
    scope = @location.employees.active.joins(:positions)
    return scope if @section_mode == "all"

    scope.where(positions: { section: @section_mode })
  end

  def shifts_for_section
    scope = @schedule.shifts.joins(:position)
    return scope if @section_mode == "all"

    scope.where(positions: { section: @section_mode })
  end

  def public_schedule_unlocked?
    session[public_schedule_session_key] == true
  end

  def public_schedule_session_key
    "public_schedule_account_#{@account.id}"
  end

  def public_schedule_params(overrides = {})
    {
      schedule_id: @schedule&.id,
      view: @view_mode,
      section: @section_mode
    }.merge(overrides).compact
  end
end
