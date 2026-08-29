require "test_helper"

class Api::V1::ColorsControllerTest < ActionDispatch::IntegrationTest
  # --- Index -------------------------------------------------------------

  test "lists every color by name" do
    get api_v1_colors_url

    assert_response :success
    assert_equal [ "autumn-ochre", "deep-indigo", "ink-black", "paper-white", "process-cyan", "signal-red" ],
      json.map { |c| c["name"] }
  end

  test "filters colors by tag" do
    get api_v1_colors_url(tag: "brand")

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colors by hex" do
    get api_v1_colors_url(hex: "E30613")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "accepts a hex filter with a leading hash" do
    get api_v1_colors_url(hex: "#e30613")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colors by palette name" do
    get api_v1_colors_url(palette: "Brand Core")

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "filters colors by palette id" do
    get api_v1_colors_url(palette: palettes(:brand).id)

    assert_equal [ "ink-black", "paper-white", "signal-red" ], json.map { |c| c["name"] }
  end

  test "combines color filters" do
    get api_v1_colors_url(palette: "Brand Core", tag: "primary")

    assert_equal [ "signal-red" ], json.map { |c| c["name"] }
  end

  test "returns an empty array when no color matches" do
    get api_v1_colors_url(hex: "#ABCDEF")

    assert_response :success
    assert_equal [], json
  end

  test "returns an empty array for an unknown palette filter" do
    get api_v1_colors_url(palette: "no-such-palette")

    assert_equal [], json
  end

  # --- Show --------------------------------------------------------------

  test "shows a color with the palettes that contain it" do
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

  test "embedded palettes are summaries without their colors" do
    get api_v1_color_url(colors(:signal_red))

    assert_equal %w[ id name tags ], json["palettes"].first.keys.sort
  end

  test "shows a color that belongs to no palette" do
    get api_v1_color_url(colors(:deep_indigo))

    assert_response :success
    assert_equal [], json["palettes"]
  end

  test "shows a cmyk sourced color with its approximate rgb" do
    get api_v1_color_url(colors(:process_cyan))

    assert_equal "cmyk", json["source_space"]
    assert_equal({ "c" => 100.0, "m" => 0.0, "y" => 0.0, "k" => 0.0 }, json["cmyk"])
    assert_equal({ "r" => 0, "g" => 255, "b" => 255 }, json["rgb"])
    assert_equal "#00FFFF", json["hex"]
  end

  test "returns 404 for an unknown color" do
    get api_v1_color_url(999_999)

    assert_response :not_found
    assert_equal "Not found", json["error"]
  end

  # --- Create ------------------------------------------------------------

  test "creates a standalone rgb color and derives its cmyk" do
    assert_difference "Color.count", 1 do
      post api_v1_colors_url, as: :json, params: { color: {
        name: "signal-blue", source_space: "rgb", r: 30, g: 90, b: 170, tags: [ "Cool", "brand" ]
      } }
    end

    assert_response :created
    assert_equal "#1E5AAA", json["hex"]
    assert_equal({ "c" => 82.4, "m" => 47.1, "y" => 0.0, "k" => 33.3 }, json["cmyk"])
    assert_equal [ "cool", "brand" ], json["tags"]
    assert_equal [], json["palettes"]
  end

  test "creates a standalone cmyk color and derives its rgb" do
    post api_v1_colors_url, as: :json, params: { color: {
      name: "process-yellow", source_space: "cmyk", c: 0, m: 0, y: 100, k: 0
    } }

    assert_response :created
    assert_equal "cmyk", json["source_space"]
    assert_equal({ "r" => 255, "g" => 255, "b" => 0 }, json["rgb"])
    assert_equal "#FFFF00", json["hex"]
  end

  test "rejects a color with no name" do
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
  # A color is shared, so being unable to correct one after it is stored
  # means living with the mistake in every palette that holds it.

  test "updates a color name and tags" do
    patch api_v1_color_url(colors(:deep_indigo)), as: :json,
      params: { color: { name: "night-indigo", tags: [ "Cool", "brand" ] } }

    assert_response :success
    assert_equal "night-indigo", json["name"]
    assert_equal [ "cool", "brand" ], json["tags"]
  end

  test "updates rgb values and rederives cmyk" do
    patch api_v1_color_url(colors(:signal_red)), as: :json,
      params: { color: { r: 30, g: 90, b: 170 } }

    assert_response :success
    assert_equal "#1E5AAA", json["hex"]
    assert_equal({ "c" => 82.4, "m" => 47.1, "y" => 0.0, "k" => 33.3 }, json["cmyk"])
  end

  test "switching source space to cmyk rederives rgb" do
    patch api_v1_color_url(colors(:signal_red)), as: :json,
      params: { color: { source_space: "cmyk", c: 0, m: 0, y: 100, k: 0 } }

    assert_response :success
    assert_equal "cmyk", json["source_space"]
    assert_equal({ "r" => 255, "g" => 255, "b" => 0 }, json["rgb"])
  end

  test "leaves palette membership alone when a color changes" do
    patch api_v1_color_url(colors(:signal_red)), as: :json, params: { color: { name: "renamed" } }

    assert_response :success
    assert_equal [ "Autumn 2026", "Brand Core" ], json["palettes"].map { |p| p["name"] }
  end

  test "editing a shared color changes it in every palette holding it" do
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

  test "returns 404 when updating an unknown color" do
    patch api_v1_color_url(999_999), as: :json, params: { color: { name: "x" } }

    assert_response :not_found
  end

  private
    def json
      JSON.parse(response.body)
    end

  # --- Sorting ------------------------------------------------------------

  test "sorts by name unless asked otherwise" do
    get api_v1_colors_url

    assert_equal Color.order(:name).pluck(:name), json.map { |color| color["name"] }
  end

  test "offers the same orders the interface does" do
    get api_v1_colors_url(sort: "dark")
    assert_equal "ink-black", json.first["name"]

    get api_v1_colors_url(sort: "light")
    assert_equal "paper-white", json.first["name"]

    get api_v1_colors_url(sort: "spectrum")
    assert_equal "ink-black", json.first["name"]
    assert_equal "paper-white", json.last["name"]
  end

  test "an unknown order is name rather than an error" do
    get api_v1_colors_url(sort: "sideways")

    assert_response :success
    assert_equal Color.order(:name).pluck(:name), json.map { |color| color["name"] }
  end

  test "sorting composes with filtering" do
    get api_v1_colors_url(tag: "brand", sort: "light")

    assert_equal [ "paper-white", "signal-red", "ink-black" ], json.map { |color| color["name"] }
  end

  # --- Duplicates and near duplicates ------------------------------------

  test "refuses a color the library already holds" do
    assert_no_difference "Color.count" do
      post api_v1_colors_url, as: :json, params: { color: {
        name: "red again", source_space: "rgb", r: 227, g: 6, b: 19
      } }
    end

    assert_response :unprocessable_content
    assert_includes json["errors"]["base"], %(#E30613 is already in the library as "signal-red")
  end

  test "refuses a near duplicate and names what it resembles" do
    assert_no_difference "Color.count" do
      post api_v1_colors_url, as: :json, params: { color: {
        name: "off-white", source_space: "rgb", r: 255, g: 255, b: 255
      } }
    end

    assert_response :unprocessable_content
    assert_match "paper-white", json["errors"]["base"].first
    assert_equal "#FAFAF8", json["similar"]["hex"]
    assert_equal colors(:paper_white).id, json["similar"]["id"]
  end

  test "accepts a near duplicate when the client confirms it" do
    assert_difference "Color.count", 1 do
      post api_v1_colors_url, as: :json, params: {
        confirm_similar: true,
        color: { name: "off-white", source_space: "rgb", r: 255, g: 255, b: 255 }
      }
    end

    assert_response :created
    assert_equal "#FFFFFF", json["hex"]
  end

  test "refuses an update that walks a color onto a near duplicate" do
    patch api_v1_color_url(colors(:deep_indigo)), as: :json,
      params: { color: { r: 255, g: 255, b: 255 } }

    assert_response :unprocessable_content
    assert_equal colors(:paper_white).id, json["similar"]["id"]
    assert_equal [ 43, 74, 138 ], colors(:deep_indigo).reload.rgb.values
  end

  test "leaves a plainly distinct color alone" do
    assert_difference "Color.count", 1 do
      post api_v1_colors_url, as: :json, params: { color: {
        name: "grass", source_space: "rgb", r: 20, g: 160, b: 40
      } }
    end

    assert_response :created
    assert_nil json["similar"]
  end

  # --- Delete -------------------------------------------------------------

  test "deletes a color no palette holds" do
    assert_difference "Color.count", -1 do
      delete api_v1_color_url(colors(:deep_indigo))
    end

    assert_response :no_content
  end

  test "refuses to delete a color a palette holds" do
    assert_no_difference "Color.count" do
      delete api_v1_color_url(colors(:signal_red))
    end

    assert_response :unprocessable_content
    assert_match "Autumn 2026 and Brand Core", json["errors"]["base"].first
  end

  test "deletes a held color when the client says that is what it means" do
    assert_difference "Color.count", -1 do
      delete api_v1_color_url(colors(:signal_red)), as: :json, params: { from_palettes: true }
    end

    assert_response :no_content
    assert_equal 2, palettes(:brand).colors.reload.size
  end

  test "reports a missing color rather than pretending to delete it" do
    delete api_v1_color_url(id: 0)

    assert_response :not_found
  end
end
