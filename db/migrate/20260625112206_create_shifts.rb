class CreateShifts < ActiveRecord::Migration[8.1]
  def change
    create_table :shifts do |t|
      t.references :schedule, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true
      t.date :shift_date, null: false
      t.time :starts_at, null: false
      t.time :ends_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :shifts, [ :schedule_id, :shift_date ]
    add_index :shifts, [ :employee_id, :shift_date ]
    add_index :shifts, [ :position_id, :shift_date ]
  end
end
