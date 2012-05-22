require 'date'

class BloodEntry
  attr_accessor :systel_total
  attr_accessor :diastol_total
  attr_accessor :pulse_total
  attr_accessor :readings
  attr_accessor :date
  
  def initialize(date)
    @date = date
    @systel_total = 0
    @diastol_total = 0
    @pulse_total = 0
    @readings = 0
  end
end


def parse_withings()
  entries = Hash.new

  File.open("script/blood.csv", "r") do |f|
  
    while (line = f.gets)
      puts "#{line}"
      columns = line.delete("\"").split(",")
    
      if(columns[0] == "BEN")

        stamp = DateTime.parse("#{columns[1]} #{columns[2]}")
        puts "#{stamp}"
        if(stamp.hour < 2)
          stamp = (stamp.to_time - 7200).to_datetime
          stamp.new_offset('+00:00')
        end
        puts "#{stamp.strftime("%Y%m%d")}"
        date = stamp.to_date #stamp.strftime("%Y%m%d");
      
        if(!entries.has_key?(date))
          puts "adding new entry #{date}"
          entries[date] = BloodEntry.new(date)
        end

        entries[date].readings = entries[date].readings+1
        entries[date].systel_total += Integer(columns[3])
        entries[date].diastol_total += Integer(columns[4])
        entries[date].pulse_total += Integer(columns[5])
      end
    end
  end
  
  entries.sort.each do|date, entry|
    puts "#{date} #{entry.readings}"
    puts "\tSystel #{entry.systel_total/entry.readings}"
    puts "\tDiastol #{entry.diastol_total/entry.readings}"
    puts "\tPulse #{entry.pulse_total/entry.readings}"
  end
  
  entries
end


parse_withings()