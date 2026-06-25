class AddSectionToPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :positions, :section, :string, null: false, default: "boh"
  end
end
