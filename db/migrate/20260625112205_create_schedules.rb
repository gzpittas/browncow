class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :schedules do |t|
      t.references :location, null: false, foreign_key: true
      t.date :week_start_date, null: false
      t.string :status, null: false, default: "draft"
      t.text :notes

      t.timestamps
    end

    add_index :schedules, [ :location_id, :week_start_date ], unique: true
  end
end
