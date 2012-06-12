Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, FACEBOOK_CONFIG['app_id'], FACEBOOK_CONFIG['secret_key']
  provider :google, GOOGLE_CONFIG['app_id'], GOOGLE_CONFIG['secret_key']
end