require Rails.root.join('script/process_withings.rb')
require Rails.root.join('script/process_body.rb')

class WelcomeController < ApplicationController
  def blood
    entries = parse_withings()
    
    @data1 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.systel_total/entry.readings}]" }.join(",")
    @data2 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.diastol_total/entry.readings}]" }.join(",")
    @data3 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.pulse_total/entry.readings}]" }.join(",")

  end
  
  def body
    entries = parse_body()
    
    @data1 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.weight}]" }.join(",")
    @data2 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.fat}]" }.join(",")
    @data3 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.water}]" }.join(",")
    @data4 = entries.sort.collect{ |date, entry| "[Date.UTC(#{date.year}, #{date.month-1}, #{date.day}), #{entry.muscle}]" }.join(",")
    
  end
end
