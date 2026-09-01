require "test_helper"

# A token that may read the library and not rewrite it.
#
# Pandatone publishes to other tools -- Stripeclub takes palettes from it --
# and until this existed the only credential on offer could also delete every
# palette in the library. A tool that never issues anything but GETs should not
# be carrying that, and on the Studio one of these is what Stripeclub holds.
class Api::V1::ReadOnlyTest < ActionDispatch::IntegrationTest
  setup { sign_in_client users(:reader) }

  test "reads everything an ordinary token can" do
    [ api_v1_palettes_url, api_v1_palette_url(palettes(:brand)),
      colors_api_v1_palette_url(palettes(:brand)), api_v1_colors_url,
      api_v1_color_url(colors(:signal_red)), api_v1_lookup_url(q: "#E30613"),
      api_v1_tags_url ].each do |url|
      get url

      assert_response :success, "GET #{url} was refused a read-only token"
    end
  end

  # Every writing route, not a sample. The rule is written on the verb exactly
  # so nothing has to be remembered as routes are added, and a test that
  # checked a single POST would pass just as happily if the rule only covered
  # that one.
  test "refuses every route that writes" do
    [ [ :post, api_v1_palettes_url ],
      [ :patch, api_v1_palette_url(palettes(:brand)) ],
      [ :delete, api_v1_palette_url(palettes(:brand)) ],
      [ :post, api_v1_colors_url ],
      [ :patch, api_v1_color_url(colors(:signal_red)) ],
      [ :delete, api_v1_color_url(colors(:signal_red)) ] ].each do |verb, url|
      public_send(verb, url)

      assert_response :forbidden, "#{verb.to_s.upcase} #{url} was allowed a read-only token"
    end
  end

  # 403, not 401. The credential is genuine and the client should not go
  # looking for a better one -- 401 means "authenticate", which would send a
  # tool into a retry loop over something retrying cannot fix.
  test "says the credential is fine and the act is not" do
    delete api_v1_palette_url(palettes(:brand))

    assert_response :forbidden
    assert_equal({ "error" => "Read only" }, json)
  end

  # Refusing has to be the whole of it. A filter that renders but does not halt
  # would answer 403 and still have done the thing.
  test "nothing is written on the way out" do
    assert_no_difference -> { Palette.count } do
      delete api_v1_palette_url(palettes(:brand))
    end

    assert_no_difference -> { Color.count } do
      post api_v1_colors_url, as: :json,
        params: { color: { name: "nope", source_space: "rgb", r: 1, g: 2, b: 3 } }
    end
  end

  # The flag is opt-in, so every account that already had a token kept exactly
  # the reach it had. This is the half that proves the guard discriminates
  # rather than simply closing writes for everyone.
  # confirm_similar, because this test is about who may write and not about the
  # too-similar rule. Without it the assertion depends on the new colour
  # staying far enough from every fixture colour, and it would start failing
  # for a reason that has nothing to do with tokens.
  test "an ordinary token still writes" do
    sign_in_client users(:keeper)

    assert_difference -> { Color.count }, 1 do
      post api_v1_colors_url, as: :json, params: {
        confirm_similar: true,
        color: { name: "still-allowed", source_space: "rgb", r: 60, g: 200, b: 90 }
      }
    end

    assert_response :created
  end

  # A read-only token is still a token. The new filter must not turn the door
  # itself into a 403 -- no credential is still unauthorized.
  test "no credential is still unauthorized, not forbidden" do
    @api_token = nil

    post api_v1_colors_url

    assert_response :unauthorized
  end
end
