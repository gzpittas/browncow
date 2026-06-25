class Shift < ApplicationRecord
  belongs_to :schedule
  belongs_to :employee
  belongs_to :position

  validates :shift_date, :starts_at, :ends_at, presence: true
  validate :shift_date_is_inside_schedule_week
  validate :employee_belongs_to_schedule_location
  validate :position_belongs_to_schedule_location
  validate :employee_is_assigned_to_position
  validate :ends_at_is_after_starts_at

  scope :ordered, -> { order(:shift_date, :starts_at) }

  def time_range
    "#{starts_at.strftime("%-l:%M")}#{starts_at.strftime("%p").downcase}-#{ends_at.strftime("%-l:%M %p")}"
  end

  private

  def shift_date_is_inside_schedule_week
    return if schedule.blank? || shift_date.blank?
    return if schedule.week_start_date <= shift_date && shift_date <= schedule.week_end_date

    errors.add(:shift_date, "must fall inside the schedule week")
  end

  def employee_belongs_to_schedule_location
    return if schedule.blank? || employee.blank?
    return if employee.location_id == schedule.location_id

    errors.add(:employee, "must belong to the schedule location")
  end

  def position_belongs_to_schedule_location
    return if schedule.blank? || position.blank?
    return if position.location_id == schedule.location_id

    errors.add(:position, "must belong to the schedule location")
  end

  def employee_is_assigned_to_position
    return if employee.blank? || position.blank?
    return if employee.positions.exists?(position.id)

    errors.add(:position, "must be assigned to the employee")
  end

  def ends_at_is_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after the start time")
  end
end
