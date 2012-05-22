
module Pipes
  def Pipes::parse_data(entries, f, schema, name)
    f.gets # skip header
    while (line = f.gets)
      line.chop!()
      puts "DATA #{line}"

      if(line == '')
        return
      end

      columns = line.delete("\"").split(",")
      if(columns.size < 2)
        next
      end
      
      e = Pipes::get_entry(entries, columns[0], name)

      schema.each do|meth, column|        
        # push item on if attribute is an array
        if(e.send(meth).is_a? Array)
          if(column.is_a? Range)
            ((column.first)..(columns.size()-1)).each do|i|
              e.send(meth).push(columns[i]);
            end
          else
            e.send(meth).push(columns[column]);
          end
        else
          e.send(meth+"=", Float(columns[column]))
        end
      end
    end
  end
  
  def Pipes::get_entry(entries, strDate, name)
    date = DateTime.parse(strDate).to_date

    if(!entries.has_key?(date))
      puts "adding new entry #{date}"
      entries[date] = Object.const_get(name).new(date)
    end

    return entries[date]
  end
  
  
  def Pipes::print_entries(entries)
    entries.sort.each do|date, entry|
      puts "\n#{date}"
      entry.public_methods(false).each do|meth|
        if(String(meth).index('=') == nil)
          puts "#{meth} == #{entry.send(meth)}"
        end
      end
    end
  end
end