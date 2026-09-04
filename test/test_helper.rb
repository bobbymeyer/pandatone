# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
  end
end

class ActionDispatch::IntegrationTest
  # The engine's routes, by their own names. The dummy application mounts the
  # engine at /pandatone, and these helpers already know that.
  include Pandatone::Engine.routes.url_helpers

  # The door is the host's. The dummy host under test/ opens its screens to a
  # cookie and its API to one token; these are the two ways through it.
  def sign_in_as(_user = nil)
    cookies[:signed_in] = "yes"
  end

  def sign_out
    cookies.delete(:signed_in)
  end

  def sign_in_client(_user = nil)
    @api_token = Dummy::API_TOKEN
  end

  # Every API test reads the body this way.
  def json
    JSON.parse(response.body)
  end

  # The verbs rather than #process, because an integration test forwards each
  # of these to a session object and never calls its own #process.
  %w[ get post patch put delete ].each do |verb|
    define_method(verb) do |path, **options|
      if @api_token
        options[:headers] = { "Authorization" => "Bearer #{@api_token}" }.merge(options[:headers] || {})
      end

      super(path, **options)
    end
  end
end
