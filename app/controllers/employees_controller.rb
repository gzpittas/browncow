class EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations
  before_action :set_location
  before_action :set_employee, only: [ :edit, :update, :deactivate ]
  before_action :set_positions, only: [ :index, :new, :create, :edit, :update ]

  def index
    @employees = @location ? @location.employees.includes(:positions).order(active: :desc, first_name: :asc, last_name: :asc) : Employee.none
    @employees_by_section = group_employees_by_section(@employees)
    @unassigned_employees = @employees.select { |employee| employee.positions.empty? }
  end

  def new
    @employee = @location.employees.build
  end

  def create
    @employee = @location.employees.build(employee_params.except(:position_ids))
    assign_positions

    if @employee.save
      redirect_to location_employees_path(@location), notice: "Employee added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @employee.assign_attributes(employee_params.except(:position_ids))
    assign_positions

    if @employee.save
      redirect_to location_employees_path(@location), notice: "Employee updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @employee.update!(active: false)
    redirect_to location_employees_path(@location), notice: "Employee marked inactive."
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

  def set_employee
    @employee = @location.employees.find(params[:id])
  end

  def set_positions
    @positions = @location ? @location.positions.ordered : Position.none
  end

  def employee_params
    params.require(:employee).permit(:first_name, :last_name, :phone_number, :email, :notes, :active, position_ids: [])
  end

  def assign_positions
    ids = Array(employee_params[:position_ids]).reject(&:blank?)
    @employee.positions = @location.positions.where(id: ids)
  end

  def group_employees_by_section(employees)
    Position::SECTIONS.keys.index_with do |section|
      employees.select { |employee| employee.positions.any? { |position| position.section == section } }
    end
  end
end
