class ChangeDefaultPositionSectionToFoh < ActiveRecord::Migration[8.1]
  def up
    change_column_default :positions, :section, from: "boh", to: "foh"
    execute "UPDATE positions SET section = 'foh' WHERE section = 'boh'"
  end

  def down
    change_column_default :positions, :section, from: "foh", to: "boh"
  end
end
