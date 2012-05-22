require 'date'
require '/Users/benjaminblack/Dropbox/Dev/bodytics/script/pipes.rb'

class KeywordEntry
  attr_accessor :date
  attr_accessor :keywords
  
  def initialize(date)
    @date = date
    @keywords = Array.new
  end
end

def parse_keywords()
  schema = {
    "keywords" => 1..5
  }
  
  entries = Hash.new

  File.open("script/keywords - Sheet1.csv", "r") do |f|
    while (line = f.gets)
      line.chop!()
      puts "MASTER #{line}"
      
      if(line =~ /^Date,Keywords/)
        Pipes::parse_data(entries, f, schema, "KeywordEntry")
      end
    end
  end
  
  Pipes::print_entries(entries)
  
  entries
end

if __FILE__ == $PROGRAM_NAME
  parse_keywords()
end