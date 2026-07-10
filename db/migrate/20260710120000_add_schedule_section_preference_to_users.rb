class AddScheduleSectionPreferenceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :schedule_section_preference, :string, default: "foh", null: false
  end
end
