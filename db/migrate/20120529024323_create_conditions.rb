class CreateConditions < ActiveRecord::Migration
  def change
    create_table :conditions do |t|
      t.integer :experiment_id
      t.string :keywords
      t.boolean :not
      t.boolean :breakfast
      t.boolean :morning
      t.boolean :lunch
      t.boolean :afternoon
      t.boolean :dinner
      t.boolean :anytime
      t.date :from
      t.date :to

      t.timestamps
    end
  end
end
