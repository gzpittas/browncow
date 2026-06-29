class AddPublicScheduleAccessToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :public_schedule_enabled, :boolean, null: false, default: false
    add_column :accounts, :public_schedule_slug, :string
    add_column :accounts, :public_schedule_password_digest, :string

    add_index :accounts, :public_schedule_slug, unique: true
  end
end
