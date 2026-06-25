class CreateEmployeePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_positions do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true

      t.timestamps
    end

    add_index :employee_positions, [ :employee_id, :position_id ], unique: true
  end
end
