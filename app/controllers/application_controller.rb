class ApplicationController < ActionController::Base
    protect_from_forgery
    before_filter :authorize
  
    def authorize
        @user = User.find_by_id(session[:user_id])

        if @user == nil || @user.fitbit_uid == nil
            redirect_to "/auth/facebook"
        end
    end
end
