require "test_helper"

# The API is the other half of this app, not a side door onto it, so it is
# closed by the same act that closes the interface. It cannot use the session
# cookie the browser carries — a cron line has no browser — so it carries a
# token instead, and the token is the only thing it will accept.
class Api::V1::AuthenticationTest < ActionDispatch::IntegrationTest
  test "refuses a request carrying no credential at all" do
    get api_v1_colors_url

    assert_response :unauthorized
  end

  test "refuses a token that belongs to nobody" do
    get api_v1_colors_url, headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
  end

  # The same envelope as every other refusal, so a client has one shape to
  # parse rather than a special case for the door.
  test "says so in the shape every other error uses" do
    get api_v1_colors_url

    assert_equal({ "error" => "Unauthorized" }, json)
  end

  # Bearer is what the README tells people to send. Token is the older spelling
  # of the same header and Rails reads both, so both are honored rather than
  # one of them failing for a reason nobody would guess.
  test "accepts the token as Bearer and as Token" do
    [ "Bearer #{users(:keeper).api_token}", "Token #{users(:keeper).api_token}" ].each do |credential|
      get api_v1_colors_url, headers: { "Authorization" => credential }

      assert_response :success, "#{credential.split.first} was refused"
    end
  end

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

  # A session cookie is not a token. Letting one in would mean any page on the
  # internet could drive the API from a signed-in browser.
  test "does not accept the browser session in place of a token" do
    sign_in_as users(:keeper)

    get api_v1_colors_url

    assert_response :unauthorized
  end

  test "regenerating the token retires the one before it" do
    user = users(:keeper)
    was = user.api_token
    user.regenerate_api_token

    get api_v1_colors_url, headers: { "Authorization" => "Bearer #{was}" }
    assert_response :unauthorized

    get api_v1_colors_url, headers: { "Authorization" => "Bearer #{user.api_token}" }
    assert_response :success
  end
end

# The health check is not part of the library, and a load balancer has no
# token. It stays open on purpose, and that is worth pinning: gating it would
# take the app down in the most confusing way available.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "answers without a credential" do
    get rails_health_check_url

    assert_response :success
  end
end
