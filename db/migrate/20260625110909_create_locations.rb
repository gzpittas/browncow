class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address_line_1
      t.string :city
      t.string :state
      t.string :postal_code
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :locations, [ :account_id, :name ]
  end
end
