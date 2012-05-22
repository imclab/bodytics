class CreateSleeps < ActiveRecord::Migration
  def change
    create_table :sleeps do |t|
      t.datetime :date
      t.integer :f_id
      t.integer :efficiency
      t.integer :time_in_bed
      t.datetime :start_time
      t.integer :awakenings
      t.integer :minutes_after_wakeup
      t.integer :minutes_asleep
      t.integer :minutes_awake
      t.integer :minutes_to_fall_asleep

      t.timestamps
    end
  end
end
