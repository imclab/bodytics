class User < ActiveRecord::Base
  has_many :sleeps, :dependent => :destroy
  has_many :foods, :dependent => :destroy
  
  def self.create_with_omniauth(auth)
    puts auth.to_yaml
    
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.first_name = auth["info"]["first_name"]
      user.last_name = auth["info"]["last_name"]
    end
  end
end
