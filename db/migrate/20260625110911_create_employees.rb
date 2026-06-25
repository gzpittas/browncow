class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :location, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.string :email
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :employees, [ :location_id, :last_name, :first_name ]
  end
end
