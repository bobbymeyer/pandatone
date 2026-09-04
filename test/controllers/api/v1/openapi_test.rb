require "test_helper"

module Pandatone
  # The API describes itself, and the description has to be true. The routes
  # are what the API can answer; the spec is what it says it answers; this
  # holds the two to each other in both directions.
  class Api::V1::OpenapiTest < ActionDispatch::IntegrationTest
    test "serves the description as JSON, to anyone" do
      get api_v1_openapi_url

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "Pandatone", json.dig("info", "title")
    end

    test "every API route is in the spec, with its verb" do
      routed.each do |path, verb|
        operation = spec.dig("paths", path, verb)
        assert operation, "#{verb.upcase} #{path} is routed but not described"
      end
    end

    test "every operation in the spec is routed" do
      spec["paths"].each do |path, operations|
        operations.except("parameters").each_key do |verb|
          assert_includes routed, [ path, verb ], "#{verb.upcase} #{path} is described but not routed"
        end
      end
    end

    test "every operation has an id, a summary and a response" do
      spec["paths"].each_value do |operations|
        operations.except("parameters").each_value do |operation|
          assert operation["operationId"].present?
          assert operation["summary"].present?
          assert operation["responses"].present?
        end
      end
    end

    private
      def spec
        @spec ||= Pandatone.openapi
      end

      # The engine's API routes as [path, verb] pairs in the spec's own
      # notation: relative to the v1 prefix, with `{key}`-style parameters.
      def routed
        @routed ||= Pandatone::Engine.routes.routes.filter_map { |route|
          next unless route.defaults[:controller].to_s.start_with?("pandatone/api/v1/")

          path = route.path.spec.to_s.delete_suffix("(.:format)").delete_prefix("/api/v1")
          path = path.gsub(":id", "{key}") if route.defaults[:controller].end_with?("palettes")
          path = path.gsub(/:(\w+)/, '{\1}')

          [ path, route.verb.downcase ]
        }.uniq.sort
      end
  end
end
