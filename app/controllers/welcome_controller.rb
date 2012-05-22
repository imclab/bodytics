class WelcomeController < ApplicationController
    def fitbit
        @user = User.find_by_id(session[:user_id])

        if @user == nil || @user.fitbit_uid == nil
            redirect_to "/auth/facebook"
        else
            client = Fitgem::Client.new(FITGEM_CONFIG[:oauth])
            access_token = client.reconnect(@user.fitbit_token, @user.fitbit_secret)

            # collect the latest sleep and food data for user
            collect_sleep(client, @user)
            collect_food(client, @user)
        end
    end

    def collect_food(client, user)
        # find the range of food data that needs to be collected
        last_food = Food.where(:user_id => user.id).last
        last_sleep = Sleep.where(:user_id => user.id).last

        if last_food != nil 
            from = last_food.date.to_date+1
            to = last_sleep.date.to_date
        else
            from = first_sleep = Sleep.where(:user_id => user.id).first.to_date
            to = last_sleep.date.to_date
        end

        puts [from..to].to_yaml

        from.upto to do |date|
            puts "here #{date}"
            data = client.foods_on_date(date)["foods"]
            data.each do |item|
                puts "hiii #{item}"
                puts "id #{item["logId"]}"
                puts "name #{item["loggedFood"]["name"]}"
                puts "type #{item["loggedFood"]["mealTypeId"]}"

                food = Food.new(:user_id => user.id, :date => date, :f_id => item["logId"], :name => item["loggedFood"]["name"], :meal_type_id => item["loggedFood"]["mealTypeId"])
                food.save!
            end
        end

    end

    def collect_sleep(client, user)
        resources = {
            :start_time => '/sleep/startTime',
            :time_in_bed => '/sleep/timeInBed',
            :minutes_asleep => '/sleep/minutesAsleep',
            :awakenings => '/sleep/awakeningsCount',
            :minutes_awake => '/sleep/minutesAwake',
            :minutes_to_fall_asleep => '/sleep/minutesToFallAsleep',
            :minutes_after_wakeup => '/sleep/minutesAfterWakeup',
            :efficiency => '/sleep/efficiency'
        }

        day_delay = 3

        sleeps = Hash.new

        # get last sleep data point
        last = Sleep.where(:user_id => user.id).last

        # three days ago from now
        now = (DateTime.now-day_delay).to_date
        period = "max";

        if last != nil then
            last = last.date.to_date

            #1d, 7d, 30d, 1w, 1m, 3m, 6m, 1y, max.	  
            days_since = (now-last).to_i


            if days_since < 1
                # no need to download new data
                puts "already uptodate"
                return
            end

            # add on day delay to get period
            days_since += day_delay

            if days_since < 8 
                period = "7d"
            elsif days_since < 31
                period = "30d"
            elsif days_since < 91
                period = "3m"
            elsif days_since < 181
                period = "6m"
            elsif days_since < 366
                period = "1y"
            end

            puts "now #{now} to then #{last} is days since #{days_since} or period #{period}"
        end

        # loop over each resource to get time serious and construct the Sleep data
        resources.each do |item, resource| 
            data = client.data_by_time_range(resource, {:base_date => "today", :period => period})
            data.each do |name, data_item|
                data_item.each do |data_items|
                    date = DateTime.parse(data_items["dateTime"]).to_date
                    value = data_items["value"]
                    puts "downloaded #{date} and #{value}"

                    if date <= last || date > now
                        puts "ignoring as before now or less than now"
                        next
                    end

                    if not sleeps.has_key? date
                        sleeps[date] = Sleep.new(:user_id => user.id, :date => date)
                    end

                    if item == :start_time
                        begin
                            sleeps[date][item] = DateTime.parse(value)
                        rescue

                        end
                    else
                        sleeps[date][item] = value
                    end
                end
            end
        end

        # save all constructed sleep data objects
        sleeps.each do |date, sleep|
            sleep.save!
            puts "S:#{date}=>#{sleep.to_yaml}"
        end
    end
    
    def magnesium
        @user = User.find_by_id(session[:user_id])

        days = @user.foods.group_by {|food| food.date }
        sleeps = @user.sleeps.group_by {|sleep| sleep.date }

        data_true = Hash.new
        data_false = Hash.new

        days.each do |date, foods|
            condition = false
            foods.each do |food|
                if food.name == "Magnesium Oxide" then
                    condition = true
                    break
                end
            end

            if sleeps[date] then
                value = sleeps[date][0].efficiency
                if condition
                    if !data_true.has_key? value
                       data_true[value] = 1
                    else
                        data_true[value] += 1
                    end
                else
                    if !data_false.has_key? value
                       data_false[value] = 1
                    else
                        data_false[value] += 1
                    end
                end
            end
        end
        
        
        @data = "['ID', 'Score', 'Magnesium', 'Magnesium', 'Count'],"
        @data << data_true.collect{ |value, count| "['#{value}', #{value}, 1, 'Magnesium', #{count}]" }.join(",\n")
        @data << ",\n"
        @data << data_false.collect{ |value, count| "['#{value}', #{value}, 0, 'No Magnesium', #{count}]" }.join(",\n")
        
    end

    def keywords
        @user = User.find_by_id(session[:user_id])

        if @user == nil || @user.fitbit_uid == nil
            redirect_to "/auth/facebook"
        else
            @keywords = Hash.new
            @efficiences = Hash.new
            @total_efficiency = 0
            
            sleep = Sleep.where(:user_id => @user.id).all
            food = Food.where(:user_id => @user.id).all

            puts "sleep size #{sleep.size}"

            sleep.each do |entry|
                puts "date #{entry.date.to_date-1} has efficiency #{entry.efficiency}"
                @total_efficiency += entry.efficiency
                # efficiency score is related to the foods consumed on the previous day
                @efficiences[entry.date.to_date-1] = entry.efficiency
            end
                
            food.each do |entry|
                keyword = entry.name.gsub("'", "");
                
                puts "using date #{entry.date.to_date} and found #{@efficiences[entry.date.to_date]}"
                
                if @efficiences[entry.date.to_date] != nil
                    if !@keywords.has_key? keyword
                        puts "adding keyword #{keyword}"
                        @keywords[keyword] = KeywordAverage.new()
                    end
                    
                    @keywords[keyword].efficiency = ((@keywords[keyword].efficiency*@keywords[keyword].n)+@efficiences[entry.date.to_date])/(@keywords[keyword].n+1)
                    @keywords[keyword].n += 1
                end
            end

            @total_efficiency /= sleep.size
            
            #puts "total efficiency #{@total_efficiency}"
            #puts @keywords.to_yaml
            
            @keywords.each do |keyword, entry|
               puts "#{keyword} is #{entry.efficiency}" 
            end
            
            
            @data = "['Product', 'Efficiency'],"
            @data << @keywords.sort_by{|keyword, entry| entry.efficiency}.select{|keyword, entry| entry.n > 10}.collect{|keyword, entry|
                "['#{keyword} [#{entry.n}]', #{entry.efficiency}]"
            }.join(",\n")
        end
    end
end

class KeywordAverage
    attr_accessor :n
    attr_accessor :efficiency

    def initialize()
        @efficiency = 0
        @n = 0
    end
end
