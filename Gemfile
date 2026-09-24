source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.3"
# activesupport depends on an unbounded "json"; json 3.0 changed JSON.parse and
# breaks ActiveSupport::JSON.decode (cookies/sessions) on Rails 8.1.3.
gem "json", "~> 2.21"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# MySQL (InnoDB) as the database for Active Record
gem "mysql2", "~> 0.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 6.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Authentication
gem "devise", "~> 5.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
  # Realistic fake data for db/seeds.rb and specs
  gem "faker", "~> 3.5"
  gem "factory_bot_rails", "~> 6.5"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "shoulda-matchers", "~> 8.0"
  # Blocks real HTTP in specs: AI calls are stubbed, never billed or flaky
  gem "webmock", "~> 3.26"
end
