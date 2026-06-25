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
    redirect_to location_schedule_path(@location, @schedule), notice: "Shift deleted."
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
    @selected_employee = @location.employees.find_by(id: params[:employee_id])
    @selected_position = @location.positions.find_by(id: params[:position_id])
    @employees = @location.employees.active.order(:last_name, :first_name)
    @positions = @location.positions.active.order(:name)

    if @selected_employee
      @positions = @selected_employee.positions.active.order(:name)
    elsif @selected_position
      @employees = @selected_position.employees.active.order(:last_name, :first_name)
    end
  end

  def set_form_context_from_shift
    @selected_employee = @shift.employee if params[:employee_id].present?
    @selected_position = @shift.position if params[:position_id].present?
    @employees = @selected_position ? @selected_position.employees.active.order(:last_name, :first_name) : @location.employees.active.order(:last_name, :first_name)
    @positions = @selected_employee ? @selected_employee.positions.active.order(:name) : @location.positions.active.order(:name)
  end

  def shift_params
    params.require(:shift).permit(:employee_id, :position_id, :shift_date, :starts_at, :ends_at, :notes)
  end

  def schedule_return_path
    view = params[:view] == "positions" ? "positions" : "employees"
    location_schedule_path(@location, @schedule, view: view)
  end
end
