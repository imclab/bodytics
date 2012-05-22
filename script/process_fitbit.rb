require 'date'
require '/Users/benjaminblack/Dropbox/Dev/bodytics/script/pipes.rb'

class FitEntry
  attr_accessor :day_score
  attr_accessor :calories_in
  attr_accessor :calories_burned
  attr_accessor :steps
  attr_accessor :distance
  attr_accessor :floors
  attr_accessor :mins_sedentary
  attr_accessor :mins_light
  attr_accessor :mins_active
  attr_accessor :mins_very_active
  attr_accessor :activity_calories
  attr_accessor :activity_score
  attr_accessor :mins_alseep
  attr_accessor :mins_awake
  attr_accessor :awakenings
  attr_accessor :time_in_bed
  attr_accessor :foods
  attr_accessor :fat
  attr_accessor :fiber
  attr_accessor :carbs
  attr_accessor :sodium
  attr_accessor :protein

  def initialize(date)
    @date = date
    @foods = Array.new
  end
end


def parse_fitbit()
  @body = {
    "day_score" => 6
  }

  @foods = {
    "calories_in" => 1
  }

  @activities = {
    "calories_burned" => 1,
    "steps" => 2,
    "distance" => 3,
    "floors" => 4,
    "mins_sedentary" => 5,
    "mins_light" => 6,
    "mins_active" => 7,
    "mins_very_active" => 8,
    "activity_calories" => 9,
    "activity_score" => 10
  }

  @sleep = {
    "mins_alseep" => 1,
    "mins_awake" => 2,
    "awakenings" => 3,
    "time_in_bed" => 4
  }
  
  entries = Hash.new

  File.open("script/fitbit.csv", "r") do |f|
    while (line = f.gets)
      line.chop!()
      puts "MASTER #{line}"
      
      if(line =~ /^Body/)
        Pipes::parse_data(entries, f, @body, "FitEntry")
      elsif(line =~ /^Foods/)
        Pipes::parse_data(entries, f, @foods, "FitEntry")
      elsif(line =~ /^Activities/)
        Pipes::parse_data(entries, f, @activities, "FitEntry")
      elsif(line =~ /^Sleep/)
        Pipes::parse_data(entries, f, @sleep, "FitEntry")
      elsif(line =~ /^food_log_(\d+)/)
        parse_food_log(entries, f, $1) 
      end
    end
  end
  
  Pipes::print_entries(entries)
  
  entries.each do|date, entry|
    puts "#{date} -> Alseep:#{entry.mins_alseep}|Awake:#{entry.mins_awake}|Awakenings:#{entry.awakenings}|Bed:#{entry.time_in_bed}"
    puts "#{entry.mins_alseep/entry.time_in_bed}"
  end
  
  entries
end


def parse_food_log(entries, f, date_str)
  e = Pipes::get_entry(entries, date_str, "FitEntry")
  
  while (line = f.gets)
    line.chop!()
    puts "FOOD_LOG #{line}"
    
    if(line == '"Daily Totals"')
      while (line = f.gets)
        puts "FOOD_LOG_2 #{line}"
        if(line == "\n")
          return
        elsif(line =~ /,"Fat","(\d+)/)
          e.fat = $1
        elsif(line =~ /,"Fiber","(\d+)/)
          e.fiber = $1
        elsif(line =~ /,"Carbs","(\d+)/)
          e.carbs = $1
        elsif(line =~ /,"Sodium","(\d+)/)
          e.sodium = $1
        elsif(line =~ /,"Protein","(\d+)/)
          e.protein = $1
        end
      end
    elsif(line =~ /^"","(.+?)","\d+"$/)
      e.foods.push($1)
    end
  end
end


if __FILE__ == $PROGRAM_NAME
  parse_fitbit()
end