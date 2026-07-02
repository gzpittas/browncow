class EmployeePosition < ApplicationRecord
  belongs_to :employee
  belongs_to :position

  before_validation :assign_employee_position_order, on: :create

  validates :position_id, uniqueness: { scope: :employee_id }
  validates :employee_position_order, numericality: { greater_than: 0 }
  validate :position_belongs_to_employee_location

  scope :ordered, -> { order(:employee_position_order, :id) }

  def insert_at!(new_position)
    transaction do
      siblings = position.employee_positions.joins(:employee).merge(Employee.active).where.not(id: id).ordered.to_a
      target_index = [[new_position.to_i - 1, 0].max, siblings.length].min
      siblings.insert(target_index, self)

      siblings.each_with_index do |employee_position, index|
        employee_position.update_columns(employee_position_order: index + 1)
      end
    end
  end

  private

  def assign_employee_position_order
    return if employee_position_order.to_i.positive? || position.blank?

    self.employee_position_order = position.employee_positions.maximum(:employee_position_order).to_i + 1
  end

  def position_belongs_to_employee_location
    return if employee.blank? || position.blank?
    return if employee.location_id == position.location_id

    errors.add(:position, "must belong to the employee's location")
  end
end
