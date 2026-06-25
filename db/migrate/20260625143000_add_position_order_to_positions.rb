class AddPositionOrderToPositions < ActiveRecord::Migration[8.1]
  class MigrationPosition < ApplicationRecord
    self.table_name = "positions"
  end

  def up
    add_column :positions, :position_order, :integer, null: false, default: 0

    say_with_time "Backfilling position order by location and division" do
      MigrationPosition.reset_column_information

      MigrationPosition.distinct.pluck(:location_id, :section).each do |location_id, section|
        MigrationPosition.where(location_id: location_id, section: section)
          .order(active: :desc, name: :asc, id: :asc)
          .each_with_index do |position, index|
            position.update_columns(position_order: index + 1)
          end
      end
    end
  end

  def down
    remove_column :positions, :position_order
  end
end
