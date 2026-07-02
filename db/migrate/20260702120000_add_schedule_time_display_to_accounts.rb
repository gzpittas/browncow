class AddScheduleTimeDisplayToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :schedule_time_display, :string, null: false, default: "stacked"
  end
end
