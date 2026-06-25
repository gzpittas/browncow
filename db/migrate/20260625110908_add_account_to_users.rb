class AddAccountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :account, null: true, foreign_key: true
  end
end
