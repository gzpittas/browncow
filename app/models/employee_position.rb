class EmployeePosition < ApplicationRecord
  belongs_to :employee
  belongs_to :position

  validates :position_id, uniqueness: { scope: :employee_id }
  validate :position_belongs_to_employee_location

  private

  def position_belongs_to_employee_location
    return if employee.blank? || position.blank?
    return if employee.location_id == position.location_id

    errors.add(:position, "must belong to the employee's location")
  end
end
