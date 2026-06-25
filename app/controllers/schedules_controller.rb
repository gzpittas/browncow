class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations
  before_action :set_location
  before_action :set_schedule, only: [ :show, :edit, :update, :destroy ]

  def index
    @schedules = @location ? @location.schedules.ordered : Schedule.none
    @current_week_start = Schedule.week_start_for(Date.current)
    @current_week_schedule = @location&.schedules&.find_by(week_start_date: @current_week_start)
  end

  def new
    @schedule = @location.schedules.build(week_start_date: Schedule.week_start_for(Date.current))
  end

  def create
    week_start_date = schedule_params[:week_start_date].presence || Schedule.week_start_for(Date.current)
    @schedule = @location.schedules.build(schedule_params.merge(week_start_date: week_start_date, status: "draft"))

    if @schedule.save
      redirect_to location_schedule_path(@location, @schedule), notice: "Weekly schedule created."
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
    @view_mode = params[:view] == "employees" ? "employees" : "positions"
    @week_dates = @schedule.week_dates
    @employees = @location.employees.active.includes(:positions).order(:last_name, :first_name)
    @positions = @location.positions.active.includes(:employees).order(:name)
    @shifts = @schedule.shifts.includes(:employee, :position).ordered
    @shifts_by_employee_and_date = @shifts.group_by { |shift| [ shift.employee_id, shift.shift_date ] }
    @shifts_by_position_and_date = @shifts.group_by { |shift| [ shift.position_id, shift.shift_date ] }
    @previous_schedule = @location.schedules.find_by(week_start_date: @schedule.week_start_date - 7.days)
    @next_schedule = @location.schedules.find_by(week_start_date: @schedule.week_start_date + 7.days)
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

  def schedule_params
    return ActionController::Parameters.new.permit(:week_start_date, :notes) if params[:schedule].blank?

    params.require(:schedule).permit(:week_start_date, :notes)
  end
end
