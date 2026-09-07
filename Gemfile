source "https://rubygems.org"

# The engine's own dependencies are in the gemspec. What is here is what the
# dummy application under test/ needs to run it.
gemspec

# its-swiss 0.9 until it is on RubyGems; then this line goes and the gemspec is
# the whole pin again.
gem "its-swiss", github: "bobbymeyer/its-swiss", branch: "say-it-once"

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
  # The dresser's client is tested at the wire.
  gem "webmock"
end
