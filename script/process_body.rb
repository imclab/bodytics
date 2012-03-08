require 'date'

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
    @weight = 0
    @fat = 0
    @water = 0
    @muscle = 0
    @muscle_no = 0
    @energy = 0
    @fat_no = 0
    @bone = 0
  end
end

def parse_body()
  entries = Hash.new

  File.open("script/body - Sheet1.csv", "r") do |f|
    while (line = f.gets)
      puts "#{line}"
      columns = line.split(",")
      
      # ignore top line and any entries with just a date
      if(columns.size > 5 && columns[0] != "Date")
        date = DateTime.parse(columns[0]).to_date
        entries[date] = BodyEntry.new(date)
        entries[date].weight = columns[1]
        entries[date].fat = columns[2]
        entries[date].water = columns[3]
        entries[date].muscle = columns[4]
        entries[date].muscle_no = columns[5]
        entries[date].energy = columns[6]
        entries[date].fat_no = columns[7]
        entries[date].bone = columns[8]
      end
    end
  end
  
  puts "Date\t\tWeigth\t% Fat\t% Water\tMuscle\tMuslce #\tEnergy\tFat #\tBone"
  entries.sort.each do|date, entry|
    puts "#{date}\t#{entry.weight}\t#{entry.fat}\t#{entry.water}\t#{entry.muscle}"
  end
  
  entries
end

parse_body()