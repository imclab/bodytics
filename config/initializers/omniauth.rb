Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, "393301207367310", "10f68c214070366a8910d42dc6079d11"
end