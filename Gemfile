source "https://rubygems.org"

# The engine's own dependencies are in the gemspec. What is here is what the
# dummy application under test/ needs to run it.
gemspec

# json 3.0.0 (7 September 2026) changed the signature of JSON.parse, and Active
# Support 8.1.3.1 still calls it the old way: a signed cookie, a JSON column, a
# schema load all raise. The lock is not committed here, so CI resolves the
# newest json. Below 3 until a Rails that takes it; the gem does not depend on it.
gem "json", "< 3"

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
