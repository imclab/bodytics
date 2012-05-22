# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120422031151) do

  create_table "foods", :force => true do |t|
    t.datetime "date"
    t.integer  "f_id"
    t.integer  "meal_type_id"
    t.string   "name"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.integer  "user_id",      :default => 3
  end

  create_table "sleeps", :force => true do |t|
    t.datetime "date"
    t.integer  "f_id"
    t.integer  "efficiency"
    t.integer  "time_in_bed"
    t.datetime "start_time"
    t.integer  "awakenings"
    t.integer  "minutes_after_wakeup"
    t.integer  "minutes_asleep"
    t.integer  "minutes_awake"
    t.integer  "minutes_to_fall_asleep"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.integer  "user_id",                :default => 3
  end

  create_table "users", :force => true do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "fitbit_uid"
    t.string   "fitbit_token"
    t.string   "fitbit_secret"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

end
