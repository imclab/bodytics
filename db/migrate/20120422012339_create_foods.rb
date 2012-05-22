class CreateFoods < ActiveRecord::Migration
  def change
    create_table :foods do |t|
      t.datetime :date
      t.integer :f_id
      t.integer :meal_type_id
      t.string :name

      t.timestamps
    end
  end
end
