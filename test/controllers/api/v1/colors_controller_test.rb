require "test_helper"

class Api::V1::ColorsControllerTest < ActionDispatch::IntegrationTest
  # --- Index -------------------------------------------------------------

  test "lists every colour by name" do
    get api_v1_colors_url

    assert_response :success
    assert_equal [ "autumn-ochre", "deep-indigo", "ink-black", "paper-white", "process-cyan", "signal-red" ],
      json.map { |c| c["name"] }
  end

  test "filters colours by tag" do
    get api_v1_colors_url(tag: "brand")

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colours by hex" do
    get api_v1_colors_url(hex: "E30613")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "accepts a hex filter with a leading hash" do
    get api_v1_colors_url(hex: "#e30613")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colours by palette name" do
    get api_v1_colors_url(palette: "Brand Core")

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colours by palette id" do
    get api_v1_colors_url(palette: palettes(:brand).id)

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "combines colour filters" do
    get api_v1_colors_url(palette: "Brand Core", tag: "primary")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "returns an empty array when no colour matches" do
    get api_v1_colors_url(hex: "#ABCDEF")

    assert_response :success
    assert_equal [], json
  end

  test "returns an empty array for an unknown palette filter" do
    get api_v1_colors_url(palette: "no-such-palette")

    assert_equal [], json
  end

  # --- Show --------------------------------------------------------------

  test "shows a colour with the palettes that contain it" do
    get api_v1_color_url(colors(:signal_red))

    assert_response :success
    assert_equal "signal-red", json["name"]
    assert_equal "#E30613", json["hex"]
    assert_equal "rgb", json["source_space"]
    assert_equal({ "r" => 227, "g" => 6, "b" => 19 }, json["rgb"])
    assert_equal({ "c" => 0.0, "m" => 97.4, "y" => 91.6, "k" => 11.0 }, json["cmyk"])
    assert_equal [ "brand", "primary" ], json["tags"]
    assert_equal [ "Autumn 2026", "Brand Core" ], json["palettes"].map { |p| p["name"] }
  end

  test "embedded palettes are summaries without their colours" do
    get api_v1_color_url(colors(:signal_red))

    assert_equal %w[ id name tags ], json["palettes"].first.keys.sort
  end

  test "shows a colour that belongs to no palette" do
    get api_v1_color_url(colors(:deep_indigo))

    assert_response :success
    assert_equal [], json["palettes"]
  end

  test "shows a cmyk sourced colour with its approximate rgb" do
    get api_v1_color_url(colors(:process_cyan))

    assert_equal "cmyk", json["source_space"]
    assert_equal({ "c" => 100.0, "m" => 0.0, "y" => 0.0, "k" => 0.0 }, json["cmyk"])
    assert_equal({ "r" => 0, "g" => 255, "b" => 255 }, json["rgb"])
    assert_equal "#00FFFF", json["hex"]
  end

  test "returns 404 for an unknown colour" do
    get api_v1_color_url(999_999)

    assert_response :not_found
    assert_equal "Not found", json["error"]
  end

  # --- Create ------------------------------------------------------------

  test "creates a standalone rgb colour and derives its cmyk" do
    assert_difference "Color.count", 1 do
      post api_v1_colors_url, as: :json, params: { color: {
        name: "signal-blue", source_space: "rgb", r: 43, g: 74, b: 138, tags: [ "Cool", "brand" ]
      } }
    end

    assert_response :created
    assert_equal "#2B4A8A", json["hex"]
    assert_equal({ "c" => 68.8, "m" => 46.4, "y" => 0.0, "k" => 45.9 }, json["cmyk"])
    assert_equal [ "cool", "brand" ], json["tags"]
    assert_equal [], json["palettes"]
  end

  test "creates a standalone cmyk colour and derives its rgb" do
    post api_v1_colors_url, as: :json, params: { color: {
      name: "process-yellow", source_space: "cmyk", c: 0, m: 0, y: 100, k: 0
    } }

    assert_response :created
    assert_equal "cmyk", json["source_space"]
    assert_equal({ "r" => 255, "g" => 255, "b" => 0 }, json["rgb"])
    assert_equal "#FFFF00", json["hex"]
  end

  test "rejects a colour with no name" do
    assert_no_difference "Color.count" do
      post api_v1_colors_url, as: :json, params: { color: { source_space: "rgb", r: 0, g: 0, b: 0 } }
    end

    assert_response :unprocessable_content
    assert_includes json["errors"]["name"], "can't be blank"
  end

  test "rejects an out of range channel" do
    post api_v1_colors_url, as: :json, params: { color: {
      name: "over", source_space: "rgb", r: 256, g: 0, b: 0
    } }

    assert_response :unprocessable_content
    assert_not_empty json["errors"]["r"]
  end

  test "rejects an unknown source space" do
    post api_v1_colors_url, as: :json, params: { color: {
      name: "lab", source_space: "lab", r: 0, g: 0, b: 0
    } }

    assert_response :unprocessable_content
    assert_not_empty json["errors"]["source_space"]
  end

  # --- Update ------------------------------------------------------------
  #
  # A colour is shared, so being unable to correct one after it is stored
  # means living with the mistake in every palette that holds it.

  test "updates a colour name and tags" do
    patch api_v1_color_url(colors(:deep_indigo)), as: :json,
      params: { color: { name: "night-indigo", tags: [ "Cool", "brand" ] } }

    assert_response :success
    assert_equal "night-indigo", json["name"]
    assert_equal [ "cool", "brand" ], json["tags"]
  end

  test "updates rgb values and rederives cmyk" do
    patch api_v1_color_url(colors(:signal_red)), as: :json,
      params: { color: { r: 43, g: 74, b: 138 } }

    assert_response :success
    assert_equal "#2B4A8A", json["hex"]
    assert_equal({ "c" => 68.8, "m" => 46.4, "y" => 0.0, "k" => 45.9 }, json["cmyk"])
  end

  test "switching source space to cmyk rederives rgb" do
    patch api_v1_color_url(colors(:signal_red)), as: :json,
      params: { color: { source_space: "cmyk", c: 0, m: 0, y: 100, k: 0 } }

    assert_response :success
    assert_equal "cmyk", json["source_space"]
    assert_equal({ "r" => 255, "g" => 255, "b" => 0 }, json["rgb"])
  end

  test "leaves palette membership alone when a colour changes" do
    patch api_v1_color_url(colors(:signal_red)), as: :json, params: { color: { name: "renamed" } }

    assert_response :success
    assert_equal [ "Autumn 2026", "Brand Core" ], json["palettes"].map { |p| p["name"] }
  end

  test "editing a shared colour changes it in every palette holding it" do
    patch api_v1_color_url(colors(:signal_red)), as: :json, params: { color: { r: 0, g: 0, b: 0 } }

    get colors_api_v1_palette_url(palettes(:brand))
    assert_equal "#000000", json.find { |c| c["id"] == colors(:signal_red).id }["hex"]

    get colors_api_v1_palette_url(palettes(:autumn))
    assert_equal "#000000", json.find { |c| c["id"] == colors(:signal_red).id }["hex"]
  end

  test "rejects an invalid update and changes nothing" do
    color = colors(:signal_red)

    patch api_v1_color_url(color), as: :json, params: { color: { r: 999 } }

    assert_response :unprocessable_content
    assert_not_empty json["errors"]["r"]
    assert_equal 227, color.reload.r
  end

  test "rejects a blank name on update" do
    patch api_v1_color_url(colors(:signal_red)), as: :json, params: { color: { name: "" } }

    assert_response :unprocessable_content
    assert_includes json["errors"]["name"], "can't be blank"
  end

  test "returns 404 when updating an unknown colour" do
    patch api_v1_color_url(999_999), as: :json, params: { color: { name: "x" } }

    assert_response :not_found
  end

  private
    def json
      JSON.parse(response.body)
    end
end
