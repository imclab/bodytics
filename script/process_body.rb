require 'date'
require '/Users/benjaminblack/Dropbox/Dev/bodytics/script/pipes.rb'

class BodyEntry
  attr_accessor :weight
  attr_accessor :fat
  attr_accessor :water
  attr_accessor :muscle
  attr_accessor :muscle_no
  attr_accessor :energy
  attr_accessor :fat_no
  attr_accessor :bone
  
  def initialize(date)
    @date = date
  end
end

def parse_body()
  schema = {
    "weight" => 1,
    "fat" => 2,
    "water" => 3,
    "muscle" => 4,
    "muscle_no" => 5,
    "energy" => 6,
    "fat_no" => 7,
    "bone" => 8
  }
  
  entries = Hash.new

  File.open("script/body.csv", "r") do |f|
    while (line = f.gets)
      puts "#{line}"

      # ignore top line
      if(line.chop() != "Date")
        Pipes::parse_data(entries, f, schema, "BodyEntry")
      end
    end
  end
  
  Pipes::print_entries(entries)
  
  entries
end

if __FILE__ == $PROGRAM_NAME
  parse_body()
end