class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!

  def show
    @locations_count = current_user.account.locations.count
    @positions_count = Position.joins(:location).where(locations: { account_id: current_user.account_id }).count
    @employees_count = Employee.joins(:location).where(locations: { account_id: current_user.account_id }).count
    @setup_complete = @locations_count.positive? && @positions_count.positive? && @employees_count.positive?
    @first_active_location = current_user.account.locations.active.order(:name).first
    @current_week_schedule = @first_active_location&.schedules&.find_by(week_start_date: Schedule.week_start_for(Date.current))
  end
end
