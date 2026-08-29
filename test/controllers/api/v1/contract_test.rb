require "test_helper"

# The whole of v1, snapshotted. Every shape a consumer can receive is written
# out here longhand — the payloads, the parameters that change them, and the
# error envelopes — so that a change to any of them fails in the one file
# whose job is to notice. Treat a failure here as a version bump rather than
# a fix.
#
# Behavior lives in the controller tests beside this one. What this file pins
# is the wire format: keys, their order, and their types.
class Api::V1::ContractTest < ActionDispatch::IntegrationTest
  test "the palette colors endpoint returns exactly this shape" do
    get colors_api_v1_palette_url("Brand Core")

    assert_response :success
    assert_equal "application/json", response.media_type

    expected = [
      {
        "id" => colors(:signal_red).id,
        "name" => "signal-red",
        "hex" => "#E30613",
        "rgb" => { "r" => 227, "g" => 6, "b" => 19 },
        "cmyk" => { "c" => 0.0, "m" => 97.4, "y" => 91.6, "k" => 11.0 },
        "source_space" => "rgb",
        "tags" => [ "brand", "primary" ]
      },
      {
        "id" => colors(:ink_black).id,
        "name" => "ink-black",
        "hex" => "#111111",
        "rgb" => { "r" => 17, "g" => 17, "b" => 17 },
        "cmyk" => { "c" => 0.0, "m" => 0.0, "y" => 0.0, "k" => 93.3 },
        "source_space" => "rgb",
        "tags" => [ "brand", "neutral" ]
      },
      {
        "id" => colors(:paper_white).id,
        "name" => "paper-white",
        "hex" => "#FAFAF8",
        "rgb" => { "r" => 250, "g" => 250, "b" => 248 },
        "cmyk" => { "c" => 0.0, "m" => 0.0, "y" => 0.8, "k" => 2.0 },
        "source_space" => "rgb",
        "tags" => [ "brand", "neutral" ]
      }
    ]

    assert_equal expected, JSON.parse(response.body)
  end

  test "color keys appear in a stable order" do
    get colors_api_v1_palette_url("Brand Core")

    JSON.parse(response.body).each do |color|
      assert_equal %w[ id name hex rgb cmyk source_space tags ], color.keys
      assert_equal %w[ r g b ], color["rgb"].keys
      assert_equal %w[ c m y k ], color["cmyk"].keys
    end
  end

  test "the two documented consumer questions are answerable in one call each" do
    # "Give me the colors of the palette tagged active."
    get api_v1_palettes_url(tag: "active")
    active = JSON.parse(response.body)
    assert_not_empty active

    get colors_api_v1_palette_url(active.first["id"])
    assert_response :success
    assert_not_empty JSON.parse(response.body)

    # "Which palettes contain #E30613?"
    get api_v1_palettes_url(color: "#E30613")
    assert_response :success
    assert_equal [ "Autumn 2026", "Brand Core" ], JSON.parse(response.body).map { |p| p["name"] }
  end


  # --- Parameters that change a payload ------------------------------------

  test "collections take a sort, and an unknown one is name" do
    %w[ name added modified spectrum dark light sideways ].each do |sort|
      get api_v1_colors_url(sort: sort)
      assert_response :success
      assert_equal Color.count, json.size, "sort=#{sort} changed the size of the collection"
    end

    get api_v1_colors_url(sort: "light")
    assert_equal "paper-white", json.first["name"]
  end

  test "a palette's colors keep their own order unless a sort is asked for" do
    get colors_api_v1_palette_url(palettes(:brand))
    assert_equal [ "signal-red", "ink-black", "paper-white" ], json.map { |c| c["name"] }

    get colors_api_v1_palette_url(palettes(:brand), sort: "light")
    assert_equal [ "paper-white", "signal-red", "ink-black" ], json.map { |c| c["name"] }
  end

  test "both collections filter by a color value written any of three ways" do
    [ "#E30613", "227, 6, 19", "0, 97.4, 91.6, 11" ].each do |value|
      get api_v1_colors_url(color: value)
      assert_equal [ "signal-red" ], json.map { |c| c["name"] }, "colors did not match #{value}"

      get api_v1_palettes_url(color: value)
      assert_equal [ "Autumn 2026", "Brand Core" ], json.map { |p| p["name"] }, "palettes did not match #{value}"
    end
  end

  test "hex remains the name v1 published for that filter" do
    get api_v1_colors_url(hex: "E30613")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  # --- The lookup ----------------------------------------------------------

  test "the lookup returns exactly this shape for a stored color" do
    get api_v1_lookup_url(q: "#E30613")

    assert_response :success
    assert_equal %w[ query hex rgb build colors palettes nearest ], json.keys
    assert_equal "#E30613", json["hex"]
    assert_equal({ "r" => 227, "g" => 6, "b" => 19 }, json["rgb"])
    assert_nil json["build"]
    assert_equal [ "signal-red" ], json["colors"].map { |c| c["name"] }
    assert_equal [ "Autumn 2026", "Brand Core" ], json["palettes"].map { |p| p["name"] }
    assert_nil json["nearest"], "nothing is nearest when the value matched exactly"
  end

  test "the lookup names the build it read, and the nearest color it holds" do
    get api_v1_lookup_url(q: "0, 0, 0, 2")

    assert_equal({ "c" => 0.0, "m" => 0.0, "y" => 0.0, "k" => 2.0 }, json["build"])
    assert_empty json["colors"]
    assert_equal "paper-white", json["nearest"]["name"]
  end

  test "the lookup refuses a value it cannot read" do
    get api_v1_lookup_url(q: "wat")

    assert_response :unprocessable_content
    assert_equal({ "q" => [ "is not a hex, an RGB triple or a CMYK build" ] }, json["errors"])
  end

  # --- Tags ----------------------------------------------------------------

  test "the tags endpoint returns exactly this shape" do
    get api_v1_tags_url

    assert_equal %w[ colors palettes ], json.keys
    assert_equal Color.all_tags, json["colors"]
    assert_equal Palette.all_tags, json["palettes"]
  end

  # --- Error envelopes -----------------------------------------------------

  test "a validation failure is errors keyed by attribute" do
    post api_v1_colors_url, as: :json, params: { color: { name: "", source_space: "rgb", r: 1, g: 2, b: 3 } }

    assert_response :unprocessable_content
    assert_equal %w[ errors ], json.keys
    assert_includes json["errors"]["name"], "can't be blank"
  end

  test "a near duplicate is refused with the swatch it resembles attached" do
    post api_v1_colors_url, as: :json,
      params: { color: { name: "off-white", source_space: "rgb", r: 255, g: 255, b: 255 } }

    assert_response :unprocessable_content
    assert_equal %w[ errors similar ], json.keys
    assert_equal colors(:paper_white).id, json["similar"]["id"]
  end

  test "confirm_similar creates it anyway" do
    post api_v1_colors_url, as: :json, params: {
      confirm_similar: true,
      color: { name: "off-white", source_space: "rgb", r: 255, g: 255, b: 255 }
    }

    assert_response :created
  end

  test "deleting a held color is refused until from_palettes says so" do
    delete api_v1_color_url(colors(:signal_red))
    assert_response :unprocessable_content
    assert_match "Autumn 2026 and Brand Core", json["errors"]["base"].first

    delete api_v1_color_url(colors(:signal_red)), as: :json, params: { from_palettes: true }
    assert_response :no_content
  end

  test "a missing record is a bare error, not a validation envelope" do
    get api_v1_color_url(id: 0)

    assert_response :not_found
    assert_equal({ "error" => "Not found" }, json)
  end
end
