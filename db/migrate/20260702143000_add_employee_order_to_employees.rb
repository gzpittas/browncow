class AddEmployeeOrderToEmployees < ActiveRecord::Migration[8.1]
  class MigrationEmployee < ApplicationRecord
    self.table_name = "employees"

    scope :active_first_alphabetical, -> { order(active: :desc, first_name: :asc, last_name: :asc, id: :asc) }
  end

  class MigrationPosition < ApplicationRecord
    self.table_name = "positions"

    has_many :migration_employee_positions,
      class_name: "AddEmployeeOrderToEmployees::MigrationEmployeePosition",
      foreign_key: :position_id
  end

  class MigrationEmployeePosition < ApplicationRecord
    self.table_name = "employee_positions"

    belongs_to :migration_employee,
      class_name: "AddEmployeeOrderToEmployees::MigrationEmployee",
      foreign_key: :employee_id
  end

  def up
    add_column :employee_positions, :employee_position_order, :integer, null: false, default: 0

    MigrationPosition.find_each do |position|
      position.migration_employee_positions
        .joins(:migration_employee)
        .merge(MigrationEmployee.active_first_alphabetical)
        .each_with_index do |employee_position, index|
          employee_position.update_columns(employee_position_order: index + 1)
        end
    end
  end

  def down
    remove_column :employee_positions, :employee_position_order
  end
end
