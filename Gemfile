source "https://rubygems.org"

# The engine's own dependencies are in the gemspec. What is here is what the
# dummy application under test/ needs to run it.
gemspec

gem "puma"
# Tags are queried with SQLite's json_each; the engine is written for SQLite
# and the dummy runs on it.
gem "sqlite3", ">= 2.1"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "bundler-audit", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
