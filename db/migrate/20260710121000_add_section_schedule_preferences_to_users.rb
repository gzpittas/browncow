class AddSectionSchedulePreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :schedule_foh_view_preference, :string, default: "positions", null: false
    add_column :users, :schedule_boh_view_preference, :string, default: "positions", null: false
    add_column :users, :schedule_foh_employee_order_preference, :string, default: "alphabetical", null: false
    add_column :users, :schedule_boh_employee_order_preference, :string, default: "alphabetical", null: false
  end
end
