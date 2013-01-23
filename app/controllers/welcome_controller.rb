require 'rinruby'

class WelcomeController < ApplicationController
    def index
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
        
        @experiments = Experiment.all
        
        sample_size = 10

R.eval <<EOF
  x <- rnorm(#{sample_size})
EOF
        
        @test = R.pull "as.numeric(summary(x))"
    end

    def collect_food(client, user)
        # find the range of food data that needs to be collected
        last_food = Food.where(:user_id => user.id).last
        last_sleep = Sleep.where(:user_id => user.id).last

        if last_food != nil 
            from = last_food.date.to_date+1
            to = last_sleep.date.to_date
        else
            from = first_sleep = Sleep.where(:user_id => user.id).first.date.to_date
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
        else 
            period = "max"
        end

        # loop over each resource to get time serious and construct the Sleep data
        resources.each do |item, resource| 
            data = client.data_by_time_range(resource, {:base_date => "today", :period => period})
            data.each do |name, data_item|
                data_item.each do |data_items|
                    date = DateTime.parse(data_items["dateTime"]).to_date
                    value = data_items["value"]
                    puts "downloaded #{date} and #{value}"

                    if last != nil && (date <= last || date > now)
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
    
    def experiment
        @user = User.find_by_id(session[:user_id])
        
        experiment = Experiment.find_by_id(params[:id])

        days = @user.foods.group_by {|food| food.date.to_date }
        
        # efficiency score is related to the foods consumed on the previous day
        sleeps = @user.sleeps.group_by {|sleep| sleep.date.to_date-1 }

        # keywords[keyword][sleep_efficiency] => count
        keywords = Hash.new
        experiment.conditions.each do |condition|
           keywords[condition.label] = DataSet.new 
        end
        
        keywords["all"] = DataSet.new
        
        days.each do |date, foods|
            # ignore day when we don't have sleep score
            if !sleeps.has_key?(date) || sleeps[date][0].efficiency == 0
               next 
            end

            
            puts "score #{sleeps[date][0].efficiency} #{sleeps[date][0].efficiency == 0}"
            
            # score
            value = sleeps[date][0].efficiency
            
            # ignore outliers
            if value < 75 || value > 99
                next
            end
            
            # keep track of all
            keywords["all"].data.increment(value)

            
            experiment.conditions.each do |condition|
                search = true
                if condition.from == nil
                    #to
                    if condition.to < date
                        search = false
                    end
                elsif condition.to == nil
                    #from
                    if condition.from > date
                        search = false
                    end
                else
                    #range
                    if condition.to < date || condition.from > date
                        search = false
                    end
                end
                
                found = false
                
                if search
                    foods.each do |food|
                        case food.meal_type_id
                        when 1
                            if !condition.breakfast
                                next
                            end
                        when 2
                            if !condition.morning
                                next
                            end
                        when 3
                            if !condition.lunch
                                next
                            end
                        when 4
                            if !condition.afternoon
                                next
                            end
                        when 5
                            if !condition.dinner
                                next
                            end
                        when 7
                            if !condition.anytime
                                next
                            end
                        end
                    
                        if food.name.match(/#{condition.keywords}/mi) != nil
                            found = true
                            break
                        end
                    end
                end
                
                found = (found == !condition.not)
                
                if found && search
                    keywords[condition.label].data.increment(value)
                else
                    keywords[condition.label].vs.increment(value)
                end
            end
        end

        
        @data = "['ID', 'Score', 'Group', 'Group', 'Count'],"
        @data << keywords.keys.each_with_index.collect{ |keyword,i| keywords[keyword].data.collect{ |value, count| "['#{value}', #{value}, #{i}, '#{keyword}', #{count}]"}.join(",\n")}.join(",\n")
        
        @stats = Array.new
        
        keywords.each do |keyword, set|
            stat = Stat.new(keyword)
            @stats << stat
        
            all_data = Array.new
            
            set.data.each do |value, count|
                
               stat.mean += value*count 
               stat.total_count += count
               
               (1..count).each do |i|
                   all_data.push(value)
               end
            end
            
            stat.median = median(all_data)
            stat.q1 = percentile(all_data, 0.25)
            stat.q2 = percentile(all_data, 0.50)
            stat.q3 = percentile(all_data, 0.75)
            stat.q4 = percentile(all_data, 1)
            
            stat.mean /= stat.total_count
            pmf = Hash.new
            
            set.data.each do |value, count|
               stat.variance += ((value-stat.mean)*(value-stat.mean)*count)
               # pmf is a normalized histogram
               stat.pmf[value] = (count.to_f / stat.total_count)
            end
            
            stat.variance /= stat.total_count
            stat.standard_deviation = Math.sqrt(stat.variance)
            
            edf_sum = 0
            (60..100).each do |score|
                edf_sum += stat.pmf[score]
                stat.edf[score] = edf_sum
            end
            
            
            
            vs_all_data = Array.new
            set.vs.each do |value, count|
               stat.vs_mean += value*count 
               stat.vs_total_count += count
               
               (1..count).each do |i|
                   vs_all_data.push(value)
               end
            end
            
            stat.vs_median = median(vs_all_data)
            stat.vs_q1 = percentile(vs_all_data, 0.25)
            stat.vs_q2 = percentile(vs_all_data, 0.50)
            stat.vs_q3 = percentile(vs_all_data, 0.75)
            stat.vs_q4 = percentile(vs_all_data, 1)
            
            stat.vs_mean /= stat.vs_total_count
            pmf = Hash.new
            
            set.vs.each do |value, count|
               stat.vs_variance += ((value-stat.vs_mean)*(value-stat.vs_mean)*count)
               # pmf is a normalized histogram
               stat.vs_pmf[value] = (count.to_f / stat.vs_total_count)
            end
            
            stat.vs_variance /= stat.vs_total_count
            stat.vs_standard_deviation = Math.sqrt(stat.vs_variance)
            stat.data = set.data
            stat.vs = set.vs
            
            edf_sum = 0
            (60..100).each do |score|
                edf_sum += stat.vs_pmf[score]
                stat.vs_edf[score] = edf_sum
            end
        end
        
        
        @pmf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @pmf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| stat.pmf[score].round(2)}.join(", ")}]"}.join(",\n")
        
        @edf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @edf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| stat.edf[score].round(2)}.join(", ")}]"}.join(",\n")
        
        @cdf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @cdf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| Normdist.normdist(score, stat.mean, stat.standard_deviation, true).round(2)}.join(", ")}]"}.join(",\n")
        
        @stats.each do |stat|
            if stat.label == "all"
                next
            end
            
            std_of_diff = Math.sqrt((stat.variance/stat.total_count)+(stat.vs_variance/stat.vs_total_count))
            delta = (stat.mean-stat.vs_mean).abs
  
            # one sided

            stat.p_value = 1-Normdist.normdist(delta, 0, std_of_diff, true)
        end
    end
    
    def median(ary)
      return nil if ary.empty?
      mid, rem = ary.length.divmod(2)
      if rem == 0
        ary.sort[mid-1,2].inject(:+) / 2.0
      else
        ary.sort[mid]
      end
    end
    
    def percentile(array, percentile)
      array.sort[(percentile * array.length).ceil - 1]
    end
end

class Stat
    attr_accessor :label
    attr_accessor :p_value
    
    attr_accessor :data
    attr_accessor :mean
    attr_accessor :variance
    attr_accessor :standard_deviation
    attr_accessor :pmf
    attr_accessor :edf
    attr_accessor :total_count
    attr_accessor :random_mean
    attr_accessor :median
    attr_accessor :q1
    attr_accessor :q2
    attr_accessor :q3
    attr_accessor :q4
    
    attr_accessor :vs
    attr_accessor :vs_mean
    attr_accessor :vs_variance
    attr_accessor :vs_standard_deviation
    attr_accessor :vs_pmf
    attr_accessor :vs_edf
    attr_accessor :vs_total_count
    attr_accessor :vs_random_mean
    attr_accessor :vs_median
    attr_accessor :vs_q1
    attr_accessor :vs_q2
    attr_accessor :vs_q3
    attr_accessor :vs_q4
    
    def initialize(label)
        @label = label
        @p_value = 0.0
        
        @mean = 0.0
        @random_mean = 0.0
        @variance = 0.0
        @standard_deviation = 0.0
        @total_count = 0.0
        @pmf = Array.new
        @edf = Array.new
        
        @vs_mean = 0.0
        @vs_random_mean = 0.0
        @vs_variance = 0.0
        @vs_standard_deviation = 0.0
        @vs_total_count = 0.0
        @vs_pmf = Array.new
        @vs_edf = Array.new
        
        (0..100).each do |value|
           @pmf[value] = 0
           @edf[value] = 0
           @vs_pmf[value] = 0
           @vs_edf[value] = 0
        end
    end
    
    def to_string
        "mean=#{mean} "+
        "variance=#{variance} "+
        "std=#{standard_deviation} "+
        "count=#{total_count} "+
        "vs_mean=#{vs_mean} "+
        "vs_variance=#{vs_variance} "+
        "vs_std=#{vs_standard_deviation} "+
        "vs_count=#{vs_total_count}"
    end
end

class DataSet
   attr_accessor :data
   attr_accessor :vs
   attr_accessor :p
    
   def initialize()
       @data = IncrementHash.new
       @vs = IncrementHash.new
       @p = 0.0
   end
end

class IncrementHash < Hash
    def initialize
       super 
    end
    
    def increment(value)
        if self.has_key? value
            self[value] += 1
        else
            self[value] = 1
        end
    end
end


module Normdist
  def self.normdist x, mean, std, cumulative
    if cumulative
      phi_around x, mean, std
    else
      tmp = 1/((Math.sqrt(2*Math::PI)*std))
      tmp * Math.exp(-0.5 * ((x-mean)/std ** 2))
    end
  end

  # fractional error less than 1.2 * 10 ^ -7.
  def self.erf z
    t = 1.0 / (1.0 + 0.5 * z.abs);

    # use Horner's method
    ans = 1 - t * Math.exp( -z*z - 1.26551223 +
    t * ( 1.00002368 +
    t * ( 0.37409196 +
    t * ( 0.09678418 +
    t * (-0.18628806 +
    t * ( 0.27886807 +
    t * (-1.13520398 +
    t * ( 1.48851587 +
    t * (-0.82215223 +
    t * ( 0.17087277))))))))))
    z >= 0 ? ans : -ans
  end

  # cumulative normal distribution
  def self.phi z
    return 0.5 * (1.0 + erf(z / (Math.sqrt(2.0))));
  end

  # cumulative normal distribution with mean mu and std deviation sigma
  def self.phi_around z, mu, sigma
    return phi((z - mu) / sigma);
  end
end