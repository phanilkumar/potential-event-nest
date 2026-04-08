source "https://rubygems.org"

ruby "3.2.2"

gem "rails", "~> 7.1.2"
gem "pg", "~> 1.5"
gem "puma", "~> 6.4"
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 2.7"
gem "jbuilder", "~> 2.11"
gem "rack-cors", "~> 2.0"
gem "sidekiq", "~> 7.2"
gem "kaminari", "~> 1.2"
gem "ransack", "~> 4.1"
gem "aasm", "~> 5.5"
gem "bootsnap", require: false

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.2"
  gem "pry-rails"
  gem "debug", platforms: %i[mri windows]
end

group :test do
  gem "shoulda-matchers", "~> 5.3"
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
end
