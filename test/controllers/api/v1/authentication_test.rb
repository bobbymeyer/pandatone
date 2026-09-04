require "test_helper"

module Pandatone
  # The door is the host's. What the engine promises is that every endpoint
  # stands behind it: each inherits from the host's API controller, so whatever
  # that controller refuses, the engine refuses too. The dummy host under test/
  # opens to one token; a real one looks tokens up.
  class Api::V1::AuthenticationTest < ActionDispatch::IntegrationTest
    test "closes every endpoint, not only the ones that read" do
      requests = [
        [ :get, api_v1_palettes_url ], [ :get, api_v1_palette_url(palettes(:brand)) ],
        [ :get, colors_api_v1_palette_url(palettes(:brand)) ], [ :post, api_v1_palettes_url ],
        [ :patch, api_v1_palette_url(palettes(:brand)) ], [ :delete, api_v1_palette_url(palettes(:brand)) ],
        [ :get, api_v1_colors_url ], [ :get, api_v1_color_url(colors(:signal_red)) ],
        [ :post, api_v1_colors_url ], [ :patch, api_v1_color_url(colors(:signal_red)) ],
        [ :delete, api_v1_color_url(colors(:signal_red)) ],
        [ :get, api_v1_lookup_url(q: "#E30613") ], [ :get, api_v1_tags_url ]
      ]

      requests.each do |verb, url|
        public_send(verb, url)

        assert_response :unauthorized, "#{verb.to_s.upcase} #{url} answered without a token"
      end
    end

    # A session cookie is not a token. Letting one in would mean any page on
    # the internet could drive the API from a signed-in browser.
    test "does not accept the browser session in place of a token" do
      sign_in_as

      get api_v1_colors_url

      assert_response :unauthorized
    end

    test "the host's token opens it" do
      sign_in_client

      get api_v1_colors_url

      assert_response :success
    end

    # A tool has to be able to read the door before it has a key.
    test "the API's description of itself is not behind the token" do
      get api_v1_openapi_url

      assert_response :success
      assert_equal "3.1.0", json["openapi"]
    end
  end
end
