class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations, except: [ :current ]
  before_action :set_location, except: [ :current ]
  before_action :set_schedule, only: [ :show, :edit, :update, :destroy, :print, :publish, :unpublish ]
  before_action :ensure_schedule_editable!, only: [ :edit, :update, :destroy ]

  def index
    @schedules = @location ? @location.schedules.ordered : Schedule.none
    @current_week_start = Schedule.week_start_for(Date.current)
    @current_week_schedule = @location.present? ? Schedule.current_for(@location) : nil
  end

  def new
    @selected_source_schedule = selected_source_schedule
    selected_week = params[:week_start_date].presence || default_new_schedule_week_start(@selected_source_schedule)
    @schedule = @location.schedules.build(week_start_date: selected_week)
  end

  def create
    week_start_date = schedule_params[:week_start_date].presence || Schedule.week_start_for(Date.current)
    @selected_source_schedule = selected_source_schedule
    @schedule = @location.schedules.build(
      schedule_params.slice(:notes).merge(week_start_date: week_start_date, status: "draft")
    )

    if create_schedule_with_optional_copy
      notice = @selected_source_schedule.present? ? "Weekly schedule created and shifts copied." : "Weekly schedule created."
      redirect_to created_schedule_path, notice: notice
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

  def publish
    @schedule.update!(status: "published")

    redirect_to location_schedule_path(@location, @schedule), notice: "Schedule published."
  end

  def unpublish
    @schedule.update!(status: "draft")

    redirect_to location_schedule_path(@location, @schedule), notice: "Schedule unpublished. It is no longer visible publicly."
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

  def ensure_schedule_editable!
    return if @schedule.editable?

    redirect_to location_schedule_path(@location, @schedule), alert: "Unpublish this schedule before making changes."
  end

  def prepare_schedule_view
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode])
    @view_mode = store_schedule_view_mode!(params[:view].presence || schedule_view_mode_for_section(@section_mode), section: @section_mode)
    @both_view_employee_sort_mode = store_both_view_employee_sort_mode!(params[:employee_order].presence || both_view_employee_sort_mode_for_section(@section_mode), section: @section_mode)
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
    @availability_blocks = availability_blocks_for_week
    @availability_blocks_by_employee_and_date = availability_blocks_by_employee_and_date(@availability_blocks)
    @employees_by_position = @positions.index_with do |position|
      employees_for_position(position)
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

  def default_new_schedule_week_start(source_schedule)
    return Schedule.week_start_for(Date.current) if source_schedule.blank?

    week_start = source_schedule.week_start_date + 1.week
    week_start += 1.week while @location.schedules.exists?(week_start_date: week_start)
    week_start
  end

  def created_schedule_path
    return location_schedule_path(@location, @schedule) if params[:view].blank? && params[:section].blank?

    location_schedule_path(
      @location,
      @schedule,
      view: normalized_schedule_view_mode(params[:view]),
      section: normalized_schedule_section_mode(params[:section]) || current_schedule_section_mode
    )
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

  def employees_for_position(position)
    return position.ranked_active_employees if @view_mode == "both" && @both_view_employee_sort_mode == "ranked"

    position.alphabetical_active_employees
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

  def availability_blocks_for_week
    employee_ids = @employees.map(&:id)
    return EmployeeAvailabilityBlock.none if employee_ids.empty?

    EmployeeAvailabilityBlock
      .active
      .where(employee_id: employee_ids)
      .where(
        "(kind = ? AND date IN (?)) OR (kind = ? AND weekday IN (?))",
        "request_off",
        @week_dates,
        "unavailable",
        @week_dates.map(&:wday)
      )
      .order(:kind)
  end

  def availability_blocks_by_employee_and_date(blocks)
    grouped = Hash.new { |hash, key| hash[key] = [] }

    blocks.each do |block|
      availability_dates_for(block).each do |date|
        grouped[[ block.employee_id, date ]] << block
      end
    end

    grouped
  end

  def availability_dates_for(block)
    return [ block.date ].compact if block.request_off?

    @week_dates.select { |date| date.wday == block.weekday }
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
