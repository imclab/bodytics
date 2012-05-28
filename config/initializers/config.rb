FITGEM_CONFIG = Fitgem::Client.symbolize_keys(YAML.load_file(Rails.root.join("config","fitbit.yml"))[Rails.env])
FACEBOOK_CONFIG = YAML.load_file(Rails.root.join("config","facebook.yml"))[Rails.env]