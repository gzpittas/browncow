class EmployeeAvailabilityBlocksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_location
  before_action :set_employee, only: :create
  before_action :set_availability_block, only: :destroy

  def create
    availability_block = find_or_initialize_availability_block

    if availability_block.save
      redirect_to availability_return_path, notice: "#{availability_block.label} marked."
    else
      redirect_to availability_return_path, alert: availability_block.errors.full_messages.to_sentence.presence || "Availability marker could not be saved."
    end
  end

  def destroy
    label = @availability_block.label
    @availability_block.destroy

    redirect_to availability_return_path, notice: "#{label} removed."
  end

  private

  def set_location
    @location = current_user.account.locations.find(params[:location_id])
  end

  def set_employee
    @employee = @location.employees.find(availability_block_params[:employee_id])
  end

  def set_availability_block
    @availability_block = @location
      .employee_availability_blocks
      .find(params[:id])
  end

  def find_or_initialize_availability_block
    case availability_block_params[:kind]
    when "request_off"
      @employee.employee_availability_blocks.find_or_initialize_by(
        kind: "request_off",
        date: availability_date,
        active: true
      ).tap do |block|
        block.all_day = true
        block.weekday = nil
      end
    when "unavailable"
      @employee.employee_availability_blocks.find_or_initialize_by(
        kind: "unavailable",
        weekday: availability_weekday,
        active: true
      ).tap do |block|
        block.all_day = true
        block.date = nil
      end
    else
      @employee.employee_availability_blocks.build(kind: availability_block_params[:kind])
    end
  end

  def availability_date
    Date.iso8601(availability_block_params[:date].to_s)
  rescue ArgumentError
    nil
  end

  def availability_weekday
    return availability_date.wday if availability_block_params[:date].present? && availability_date.present?

    availability_block_params[:weekday].presence&.to_i
  end

  def availability_return_path
    return_to = params[:return_to].presence
    return location_employees_path(@location) if return_to.blank?

    redirect_uri = URI.parse(return_to)
    return location_employees_path(@location) if redirect_uri.host.present?

    return_to
  rescue URI::InvalidURIError
    location_employees_path(@location)
  end

  def availability_block_params
    params.require(:employee_availability_block).permit(:employee_id, :kind, :date, :weekday)
  end
end
