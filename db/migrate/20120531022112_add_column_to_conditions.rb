class AddColumnToConditions < ActiveRecord::Migration
  def change
      add_column :conditions, :label, :string
  end
end
