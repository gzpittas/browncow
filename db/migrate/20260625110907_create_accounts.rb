class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :phone_number
      t.string :email

      t.timestamps
    end
  end
end
