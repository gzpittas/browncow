class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations, except: [ :current ]
  before_action :set_location, except: [ :current ]
  before_action :set_schedule, only: [ :show, :edit, :update, :destroy, :print ]

  def index
    @schedules = @location ? @location.schedules.ordered : Schedule.none
    @current_week_start = Schedule.week_start_for(Date.current)
    @current_week_schedule = @location.present? ? Schedule.current_for(@location) : nil
  end

  def new
    selected_week = params[:week_start_date].presence || Schedule.week_start_for(Date.current)
    @schedule = @location.schedules.build(week_start_date: selected_week)
    @selected_source_schedule = selected_source_schedule
  end

  def create
    week_start_date = schedule_params[:week_start_date].presence || Schedule.week_start_for(Date.current)
    @selected_source_schedule = selected_source_schedule
    @schedule = @location.schedules.build(
      schedule_params.slice(:notes).merge(week_start_date: week_start_date, status: "draft")
    )

    if create_schedule_with_optional_copy
      notice = @selected_source_schedule.present? ? "Weekly schedule created and shifts copied." : "Weekly schedule created."
      redirect_to location_schedule_path(@location, @schedule), notice: notice
    else
      existing_schedule = @location.schedules.find_by(week_start_date: @schedule.week_start_date)

      if existing_schedule && @schedule.errors.added?(:week_start_date, :taken, value: @schedule.week_start_date)
        redirect_to location_schedule_path(@location, existing_schedule), alert: "That weekly schedule already exists."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
    prepare_schedule_view
    @previous_schedule = @location.schedules.find_by(week_start_date: @schedule.week_start_date - 7.days)
    @next_schedule = @location.schedules.find_by(week_start_date: @schedule.week_start_date + 7.days)
  end

  def print
    prepare_schedule_view
    @print_employees = Employee.where(id: @shifts.select(:employee_id)).includes(:positions).order(:first_name, :last_name) if @view_mode == "employees"

    render layout: "print"
  end

  def edit
  end

  def update
    if @schedule.update(schedule_params.slice(:notes))
      redirect_to location_schedule_path(@location, @schedule), notice: "Schedule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule.destroy
    redirect_to location_schedules_path(@location), notice: "Schedule deleted. All shifts for that week were also deleted."
  end

  def current
    destination = current_schedule_destination_for(current_user, view: params[:view], section: params[:section])

    if current_schedule_record.present?
      redirect_to destination
    elsif current_schedule_location.present?
      redirect_to destination, alert: "No current weekly schedule yet. Create this week's schedule to get started."
    else
      redirect_to destination
    end
  end

  private

  def set_locations
    @locations = current_user.account.locations.order(active: :desc, name: :asc)
  end

  def set_location
    @location = if params[:location_id].present?
      current_user.account.locations.find(params[:location_id])
    else
      @locations.first
    end
  end

  def set_schedule
    @schedule = @location.schedules.find(params[:id])
  end

  def prepare_schedule_view
    @view_mode = store_schedule_view_mode!(params[:view].presence || session[:schedule_view_mode])
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode])
    @section_label = schedule_section_label(@section_mode)
    @week_dates = @schedule.week_dates
    @mini_calendar_date = mini_calendar_date
    @positions = positions_for_section.includes(:employees).ordered
    @employees = employees_for_section
      .includes(:positions)
      .distinct
      .order(:first_name, :last_name)
    @shifts = shifts_for_section.includes(:position, employee: :positions).ordered
    @shifts_by_employee_and_date = @shifts.group_by { |shift| [ shift.employee_id, shift.shift_date ] }
    @shifts_by_position_and_date = @shifts.group_by { |shift| [ shift.position_id, shift.shift_date ] }
    @shifts_by_employee_position_and_date = @shifts.group_by { |shift| [ shift.employee_id, shift.position_id, shift.shift_date ] }
    @employees_by_position = @positions.index_with do |position|
      position.employees.select(&:active?).sort_by { |employee| [ employee.first_name.to_s.downcase, employee.last_name.to_s.downcase ] }
    end
    @current_week_schedule = Schedule.current_for(@location)
    remember_schedule_context!(location: @location, schedule: @schedule, view: @view_mode, section: @section_mode)
  end

  def schedule_params
    return ActionController::Parameters.new.permit(:week_start_date, :notes, :source_schedule_id) if params[:schedule].blank?

    params.require(:schedule).permit(:week_start_date, :notes, :source_schedule_id)
  end

  def selected_source_schedule
    source_schedule_id = schedule_params[:source_schedule_id].presence || params[:copy_from_schedule_id].presence
    return if source_schedule_id.blank?

    @location.schedules.find(source_schedule_id)
  end

  def create_schedule_with_optional_copy
    Schedule.transaction do
      @schedule.save!
      @selected_source_schedule&.copy_shifts_to!(@schedule)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
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

  def schedule_section_label(section_mode)
    return "All Divisions" if section_mode == "all"

    Position::SECTIONS.fetch(section_mode)
  end

  def mini_calendar_date
    return @schedule.week_start_date if params[:calendar_month].blank?

    Date.iso8601(params[:calendar_month])
  rescue ArgumentError
    @schedule.week_start_date
  end
end
