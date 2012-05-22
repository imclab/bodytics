class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :provider
      t.string :uid
      t.string :first_name
      t.string :last_name
      t.string :fitbit_uid
      t.string :fitbit_token
      t.string :fitbit_secret

      t.timestamps
    end
  end
end
