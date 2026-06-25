class ShiftsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_location
  before_action :set_schedule
  before_action :set_shift, only: [ :edit, :update, :destroy ]
  before_action :set_form_context, only: [ :new, :create, :edit, :update ]

  def new
    @shift = @schedule.shifts.build(
      employee: @selected_employee,
      position: @selected_position,
      shift_date: params[:shift_date].presence || @schedule.week_start_date
    )
  end

  def create
    @shift = @schedule.shifts.build(shift_params)

    if @shift.save
      redirect_to schedule_return_path, notice: "Shift saved."
    else
      set_form_context_from_shift
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shift.update(shift_params)
      redirect_to schedule_return_path, notice: "Shift updated."
    else
      set_form_context_from_shift
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to location_schedule_path(@location, @schedule, view: params[:view].presence || "positions", section: params[:section].presence || @section_mode), notice: "Shift deleted."
  end

  private

  def set_location
    @location = current_user.account.locations.find(params[:location_id])
  end

  def set_schedule
    @schedule = @location.schedules.find(params[:schedule_id])
  end

  def set_shift
    @shift = @schedule.shifts.find(params[:id])
  end

  def set_form_context
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode])
    @selected_employee = @location.employees.find_by(id: params[:employee_id])
    @selected_position = selected_position_for_section
    @employees = employee_scope_for_section.distinct.order(:first_name, :last_name)
    @positions = position_scope_for_section.ordered

    if @selected_employee
      @positions = scoped_employee_positions.ordered
    elsif @selected_position
      @employees = @selected_position.employees.active.order(:first_name, :last_name)
    end
  end

  def set_form_context_from_shift
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode] || @shift.position.section)
    @selected_employee = @shift.employee if params[:employee_id].present?
    @selected_position = @shift.position if params[:position_id].present?
    @employees = @selected_position ? @selected_position.employees.active.order(:first_name, :last_name) : employee_scope_for_section.distinct.order(:first_name, :last_name)
    @positions = @selected_employee ? scoped_employee_positions.ordered : position_scope_for_section.ordered
  end

  def shift_params
    params.require(:shift).permit(:employee_id, :position_id, :shift_date, :starts_at, :ends_at, :notes)
  end

  def schedule_return_path
    view = normalized_schedule_view_mode(params[:view])
    location_schedule_path(@location, @schedule, view: view, section: params[:section].presence || @section_mode)
  end

  def selected_position_for_section
    position = @location.positions.find_by(id: params[:position_id])
    return unless position
    return position if @section_mode == "all" || position.section == @section_mode

    nil
  end

  def employee_scope_for_section
    scope = @location.employees.active.joins(:positions)
    return scope if @section_mode == "all"

    scope.where(positions: { section: @section_mode })
  end

  def position_scope_for_section
    scope = @location.positions.active
    return scope if @section_mode == "all"

    scope.where(section: @section_mode)
  end

  def scoped_employee_positions
    scope = @selected_employee.positions.active
    return scope if @section_mode == "all"

    scope.where(section: @section_mode)
  end
end
