ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Every API test reads the body this way; it was a private method copied
  # into each file, which is also why one of them declared tests after a
  # `private` keyword.
  def json
    JSON.parse(response.body)
  end

  # Every API request needs a token, and saying so at all 118 call sites would
  # bury what each of those tests is actually about. A test that cares how the
  # door works says so itself — see api/v1/authentication_test.rb, which never
  # calls this.
  def sign_in_client(user = users(:keeper))
    @api_token = user.api_token
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
