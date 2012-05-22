class AddUserIdToSleeps < ActiveRecord::Migration
  def change
    add_column :sleeps, :user_id, :integer

  end
end
