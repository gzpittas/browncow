class AddColorToPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :positions, :color, :string, null: false, default: "#8A4F2A"
  end
end
