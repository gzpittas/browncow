class CreateEmployeeAvailabilityBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_availability_blocks do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :date
      t.integer :weekday
      t.time :starts_at
      t.time :ends_at
      t.boolean :all_day, null: false, default: true
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :employee_availability_blocks,
      [ :employee_id, :kind, :date ],
      unique: true,
      where: "active = true AND kind = 'request_off'",
      name: "index_availability_blocks_on_employee_request_date"

    add_index :employee_availability_blocks,
      [ :employee_id, :kind, :weekday ],
      unique: true,
      where: "active = true AND kind = 'unavailable'",
      name: "index_availability_blocks_on_employee_unavailable_weekday"
  end
end
