class SessionsController < ApplicationController
    skip_filter :authorize
    
  def create
    auth = request.env['omniauth.auth']
    user = User.find_by_provider_and_uid(auth["provider"], auth["uid"]) || User.create_with_omniauth(auth)
    
    session[:user_id] = user.id
    
    if user.fitbit_uid == nil
      puts "CONFIG: #{FITGEM_CONFIG[:oauth]}"
      client = Fitgem::Client.new(FITGEM_CONFIG[:oauth])
      request_token = client.request_token
      token = request_token.token
      secret = request_token.secret
      
      user.fitbit_token = token
      user.fitbit_secret = secret
      user.save!
      
      redirect_to "http://www.fitbit.com/oauth/authorize?oauth_token=#{token}"
    else
      redirect_to root_url
    end
  end
  
  def fitbit_callback
    puts params.to_yaml
    
    user = User.find_by_fitbit_token(params[:oauth_token])
    
    if user == nil
      
    else
      client = Fitgem::Client.new(FITGEM_CONFIG[:oauth])
      access_token = client.authorize(user.fitbit_token, user.fitbit_secret, { :oauth_verifier => params[:oauth_verifier] })
      
      puts 'Verifier is: '+params[:oauth_verifier]
      puts "Token is:    "+access_token.token
      puts "Secret is:   "+access_token.secret

      user_id = client.user_info['user']['encodedId']
      puts "Current User is: "+user_id
      
      user.fitbit_token = access_token.token
      user.fitbit_secret = access_token.secret
      user.fitbit_uid = user_id
      user.save!
      
      redirect_to root_url
    end
  end
end
