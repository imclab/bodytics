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
        
        @experiments = Experiment.all
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
           keywords[condition.label] = Hash.new 
        end
        
        keywords["all"] = Hash.new
        
        days.each do |date, foods|
            # ignore day when we don't have sleep score
            if !sleeps.has_key? date
               next 
            end
            
            # keep track of all
            value = sleeps[date][0].efficiency
            if keywords["all"].has_key? value
                keywords["all"][value] += 1
            else
                keywords["all"][value] = 1
            end
            
            experiment.conditions.each do |condition|
                if condition.from == nil
                    #to
                    if condition.to < date
                        next
                    end
                elsif condition.to == nil
                    #from
                    if condition.from > date
                        next
                    end
                else
                    #range
                    if condition.to < date || condition.from > date
                        next
                    end
                end
                
                found = false
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
                
                found = (found == !condition.not)
                
                if found
                    
                    value = sleeps[date][0].efficiency
                    
                    #puts "found #{condition.label} #{value}"
                    if keywords[condition.label].has_key? value
                        keywords[condition.label][value] += 1
                    else
                        keywords[condition.label][value] = 1
                    end
                end
            
            end
        end
        
        @data = "['ID', 'Score', 'Group', 'Group', 'Count'],"
        @data << keywords.keys.each_with_index.collect{ |keyword,i| keywords[keyword].collect{ |value, count| "['#{value}', #{value}, #{i}, '#{keyword}', #{count}]"}.join(",\n")}.join(",\n")
        
        @stats = Array.new
        
        keywords.each do |keyword, values|
            stat = Stat.new(keyword)
            @stats << stat
            
            values.each do |value, count|
               stat.mean += value*count 
               stat.total_count += count
            end
            
            stat.mean /= stat.total_count
            pmf = Hash.new
            
            values.each do |value, count|
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
        end
        
        
        @pmf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @pmf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| stat.pmf[score].round(2)}.join(", ")}]"}.join(",\n")
        
        @edf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @edf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| stat.edf[score].round(2)}.join(", ")}]"}.join(",\n")
        
        @cdf  = "['Sleep Score', #{keywords.keys.collect{ |keyword| "'#{keyword}'"}.join(", ")}],\n"
        @cdf << (60..100).each.collect{ |score| "['#{score}', #{@stats.collect{ |stat| Normdist.normdist(score, stat.mean, stat.standard_deviation, true).round(2)}.join(", ")}]"}.join(",\n")
        
        
        
        
        # assumption: each label is mutually exclusive! (ignore all label)
        
        @significant_tests = Array.new
        
        @stats.each_with_index do |value, index|
            if @stats[index].label == "all"
                next
            end
            
            ((index+1)..(@stats.length-1)).each do |paired_index|
                if @stats[paired_index].label == "all"
                    next 
                end
                puts "paired #{index} with #{paired_index}" 
                @significant_tests << Significant.new(@stats[index], @stats[paired_index])
           end
        end
        
        random_runs = 1000     
        
        @significant_tests.each do |significant|
            # step 1: combine data from both labels and produce a CDF
            s1 = significant.stat_1
            s2 = significant.stat_2
            
            mean = ((s1.total_count*s1.mean)+(s2.total_count*s2.mean))/(s1.total_count+s2.total_count)
            
            std_part1 = s1.total_count*(s1.standard_deviation**2)
            std_part2 = s2.total_count*(s2.standard_deviation**2)
            std_part3 = (std_part1+std_part2)/(s1.total_count+s2.total_count)
            std_part4 = (s1.total_count*s2.total_count)/((s1.total_count+s2.total_count)**2)
            std_part5 = (s1.mean-s2.mean)**2
            std_part6 = std_part4*std_part5
            std = Math.sqrt(std_part3 + std_part6)
            
            gaus = RandomGaussian.new(mean, std)
            
            
            mean_diff = (s1.mean-s2.mean).abs
            puts "mean1 #{s1.mean} std #{s1.standard_deviation}"
            puts "mean2 #{s2.mean} std #{s2.standard_deviation}"
            puts "difference in means is #{mean_diff}"
            puts "combined mean #{mean}"
            puts "combined std #{std}"
           
            # step 2: run 1000 tests to find a set of random mean differences and see if they are bigger than 
            
            bigger_diff = 0.0;
            
            (1..random_runs).each do |sample|
                (1..significant.stat_1.total_count).each do |j|
                    significant.stat_1.random_mean += gaus.rand()
                end
                
                significant.stat_1.random_mean /= significant.stat_1.total_count
                
                (1..significant.stat_2.total_count).each do |j|
                    significant.stat_2.random_mean += gaus.rand()
                end
                
                significant.stat_2.random_mean /= significant.stat_2.total_count

                #puts "set1=#{significant.stat_1.random_mean} count=#{significant.stat_1.total_count}"
                #puts "set2=#{significant.stat_2.random_mean} count=#{significant.stat_2.total_count}"

                rand_diff = significant.stat_1.random_mean-significant.stat_2.random_mean
                
                #puts "difference in means is #{mean_diff}"
                #puts "difference in random means is #{rand_diff}"

                if rand_diff.abs >= mean_diff
                    bigger_diff += 1
                end
            end
            
            significant.result = bigger_diff/random_runs
            
            puts "Probability: #{significant.result}"
        end
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

class Stat
    attr_accessor :label
    attr_accessor :mean
    attr_accessor :variance
    attr_accessor :standard_deviation
    attr_accessor :pmf
    attr_accessor :edf
    attr_accessor :total_count
    attr_accessor :random_mean
    
    def initialize(label)
        @label = label
        @mean = 0.0
        @random_mean = 0.0
        @variance = 0.0
        @standard_deviation = 0.0
        @total_count = 0.0
        @pmf = Array.new
        @edf = Array.new
        
        (0..100).each do |value|
           @pmf[value] = 0
           @edf[value] = 0
        end
    end
end

class Significant
    attr_accessor :stat_1
    attr_accessor :stat_2
    attr_accessor :result
    
    def initialize(stat_1, stat_2)
        @stat_1 = stat_1
        @stat_2 = stat_2
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

class RandomGaussian
  def initialize(mean, stddev, rand_helper = lambda { Kernel.rand })
    @rand_helper = rand_helper
    @mean = mean
    @stddev = stddev
    @valid = false
    @next = 0
  end

  def rand
    if @valid then
      @valid = false
      return @next
    else
      @valid = true
      x, y = self.class.gaussian(@mean, @stddev, @rand_helper)
      @next = y
      return x
    end
  end

  private
  def self.gaussian(mean, stddev, rand)
    theta = 2 * Math::PI * rand.call
    rho = Math.sqrt(-2 * Math.log(1 - rand.call))
    scale = stddev * rho
    x = mean + scale * Math.cos(theta)
    y = mean + scale * Math.sin(theta)
    return x, y
  end
end