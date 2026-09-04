require "test_helper"

module Pandatone
  class Api::V1::PalettesControllerTest < ActionDispatch::IntegrationTest
    setup { sign_in_client }

    # --- Index -------------------------------------------------------------

    test "lists every palette by name" do
      get api_v1_palettes_url

      assert_response :success
      assert_equal [ "Autumn 2026", "Brand Core", "Press Check", "Unfilled" ], json.map { |p| p["name"] }
    end

    test "index returns a bare array of summaries without colors" do
      get api_v1_palettes_url

      assert_kind_of Array, json
      assert_equal %w[ id name tags ], json.first.keys.sort
    end

    test "filters the index by tag" do
      get api_v1_palettes_url(tag: "active")

      assert_equal [ "Autumn 2026", "Brand Core" ], json.map { |p| p["name"] }
    end

    test "filters the index by tag case insensitively" do
      get api_v1_palettes_url(tag: "ACTIVE")

      assert_equal [ "Autumn 2026", "Brand Core" ], json.map { |p| p["name"] }
    end

    test "filters the index by contained color" do
      get api_v1_palettes_url(color: "E30613")

      assert_equal [ "Autumn 2026", "Brand Core" ], json.map { |p| p["name"] }
    end

    test "accepts a contained color with a leading hash" do
      get api_v1_palettes_url(color: "#E30613")

      assert_equal [ "Autumn 2026", "Brand Core" ], json.map { |p| p["name"] }
    end

    test "combines the tag and color filters" do
      get api_v1_palettes_url(tag: "seasonal", color: "E30613")

      assert_equal [ "Autumn 2026" ], json.map { |p| p["name"] }
    end

    test "returns an empty array when nothing matches" do
      get api_v1_palettes_url(tag: "nonexistent")

      assert_response :success
      assert_equal [], json
    end

    test "returns an empty array for an unparseable color filter" do
      get api_v1_palettes_url(color: "not-a-hex")

      assert_equal [], json
    end

    # --- Show --------------------------------------------------------------

    test "shows a palette with its colors inline in position order" do
      get api_v1_palette_url(palettes(:brand))

      assert_response :success
      assert_equal "Brand Core", json["name"]
      assert_equal [ "brand", "active" ], json["tags"]
      assert_equal [ "signal-red", "ink-black", "paper-white" ], json["colors"].map { |c| c["name"] }
    end

    test "resolves a palette by name" do
      get api_v1_palette_url("Brand Core")

      assert_response :success
      assert_equal palettes(:brand).id, json["id"]
    end

    test "resolves a palette by name case insensitively" do
      get api_v1_palette_url("brand core")

      assert_response :success
      assert_equal palettes(:brand).id, json["id"]
    end

    test "shows a palette with no colors" do
      get api_v1_palette_url(palettes(:empty))

      assert_response :success
      assert_equal [], json["colors"]
    end

    test "returns 404 for an unknown palette" do
      get api_v1_palette_url("no-such-palette")

      assert_response :not_found
      assert_equal "Not found", json["error"]
    end

    # --- Colors ------------------------------------------------------------

    test "returns just the colors of a palette in position order" do
      get colors_api_v1_palette_url(palettes(:brand))

      assert_response :success
      assert_kind_of Array, json
      assert_equal [ "signal-red", "ink-black", "paper-white" ], json.map { |c| c["name"] }
    end

    test "returns the colors of a palette addressed by name" do
      get colors_api_v1_palette_url("Autumn 2026")

      assert_equal [ "autumn-ochre", "signal-red" ], json.map { |c| c["name"] }
    end

    test "returns an empty array for a palette with no colors" do
      get colors_api_v1_palette_url(palettes(:empty))

      assert_response :success
      assert_equal [], json
    end

    test "returns 404 for the colors of an unknown palette" do
      get colors_api_v1_palette_url("no-such-palette")

      assert_response :not_found
    end

    # --- Create ------------------------------------------------------------

    test "creates a palette with nested new colors in one request" do
      assert_difference [ "Palette.count", "Color.count" ], 1 do
        post api_v1_palettes_url, as: :json, params: { palette: {
          name: "Winter 2027",
          tags: [ "Seasonal" ],
          colors: [ { name: "frost", source_space: "rgb", r: 200, g: 220, b: 255 } ]
        } }
      end

      assert_response :created
      assert_equal "Winter 2027", json["name"]
      assert_equal [ "seasonal" ], json["tags"]
      assert_equal [ "frost" ], json["colors"].map { |c| c["name"] }
      assert_equal "#C8DCFF", json["colors"].first["hex"]
    end

    test "creates a palette with no colors" do
      post api_v1_palettes_url, as: :json, params: { palette: { name: "Empty Set" } }

      assert_response :created
      assert_equal [], json["colors"]
      assert_equal [], json["tags"]
    end

    test "orders nested colors by the order they are given" do
      post api_v1_palettes_url, as: :json, params: { palette: {
        name: "Ordered",
        colors: [
          { name: "first", source_space: "rgb", r: 1, g: 1, b: 1 },
          { name: "second", source_space: "rgb", r: 2, g: 2, b: 2 },
          { name: "third", source_space: "rgb", r: 3, g: 3, b: 3 }
        ]
      } }

      assert_equal [ "first", "second", "third" ], json["colors"].map { |c| c["name"] }
      assert_equal [ 0, 1, 2 ], Palette.find(json["id"]).palette_colors.map(&:position)
    end

    test "attaches an existing color by id rather than duplicating it" do
      assert_no_difference "Color.count" do
        post api_v1_palettes_url, as: :json, params: { palette: {
          name: "Reuse",
          colors: [ { id: colors(:signal_red).id } ]
        } }
      end

      assert_response :created
      assert_equal [ colors(:signal_red).id ], json["colors"].map { |c| c["id"] }
    end

    test "derives cmyk for a nested rgb color" do
      post api_v1_palettes_url, as: :json, params: { palette: {
        name: "Derived",
        colors: [ { name: "red", source_space: "rgb", r: 220, g: 20, b: 60 } ]
      } }

      assert_equal({ "c" => 0.0, "m" => 90.9, "y" => 72.7, "k" => 13.7 }, json["colors"].first["cmyk"])
    end

    test "rejects a palette with no name" do
      assert_no_difference "Palette.count" do
        post api_v1_palettes_url, as: :json, params: { palette: { name: "" } }
      end

      assert_response :unprocessable_content
      assert_includes json["errors"]["name"], "can't be blank"
    end

    test "rejects a duplicate palette name" do
      post api_v1_palettes_url, as: :json, params: { palette: { name: "brand core" } }

      assert_response :unprocessable_content
      assert_includes json["errors"]["name"], "has already been taken"
    end

    test "rejects a palette whose nested color is invalid and creates neither" do
      assert_no_difference [ "Palette.count", "Color.count" ] do
        post api_v1_palettes_url, as: :json, params: { palette: {
          name: "Bad Nested",
          colors: [ { name: "over", source_space: "rgb", r: 999, g: 0, b: 0 } ]
        } }
      end

      assert_response :unprocessable_content
      assert_not_empty json["errors"]
    end

    test "rejects a reference to a color that does not exist" do
      post api_v1_palettes_url, as: :json, params: { palette: {
        name: "Dangling",
        colors: [ { id: 999_999 } ]
      } }

      assert_response :unprocessable_content
    end

    # --- Update ------------------------------------------------------------

    test "updates a palette name and tags" do
      patch api_v1_palette_url(palettes(:press)), as: :json,
        params: { palette: { name: "Press Check 2", tags: [ "Print", "archive" ] } }

      assert_response :success
      assert_equal "Press Check 2", json["name"]
      assert_equal [ "print", "archive" ], json["tags"]
    end

    test "leaves colors alone when the update does not mention them" do
      patch api_v1_palette_url(palettes(:brand)), as: :json, params: { palette: { tags: [ "brand" ] } }

      assert_response :success
      assert_equal [ "signal-red", "ink-black", "paper-white" ], json["colors"].map { |c| c["name"] }
    end

    test "reorders colors when given the full list in a new order" do
      palette = palettes(:brand)

      patch api_v1_palette_url(palette), as: :json, params: { palette: { colors: [
        { id: colors(:paper_white).id },
        { id: colors(:signal_red).id },
        { id: colors(:ink_black).id }
      ] } }

      assert_response :success
      assert_equal [ "paper-white", "signal-red", "ink-black" ], json["colors"].map { |c| c["name"] }
      assert_equal [ 0, 1, 2 ], palette.reload.palette_colors.map(&:position)
    end

    test "removes a color from a palette by omitting it, without deleting the color" do
      assert_no_difference "Color.count" do
        patch api_v1_palette_url(palettes(:brand)), as: :json, params: { palette: { colors: [
          { id: colors(:signal_red).id }
        ] } }
      end

      assert_response :success
      assert_equal [ "signal-red" ], json["colors"].map { |c| c["name"] }
      assert Color.exists?(colors(:ink_black).id)
    end

    test "adds a new color to an existing palette" do
      assert_difference "Color.count", 1 do
        patch api_v1_palette_url(palettes(:press)), as: :json, params: { palette: { colors: [
          { id: colors(:process_cyan).id },
          { name: "process-magenta", source_space: "cmyk", c: 0, m: 100, y: 0, k: 0 }
        ] } }
      end

      assert_response :success
      assert_equal [ "process-cyan", "process-magenta" ], json["colors"].map { |c| c["name"] }
      assert_equal({ "r" => 255, "g" => 0, "b" => 255 }, json["colors"].last["rgb"])
    end

    test "empties a palette when given an empty color list" do
      patch api_v1_palette_url(palettes(:brand)), as: :json, params: { palette: { colors: [] } }

      assert_response :success
      assert_equal [], json["colors"]
      assert_equal 3, Color.where(id: [ colors(:signal_red).id, colors(:ink_black).id, colors(:paper_white).id ]).count
    end

    test "rejects an invalid update and changes nothing" do
      palette = palettes(:brand)

      patch api_v1_palette_url(palette), as: :json, params: { palette: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Brand Core", palette.reload.name
    end

    test "rejects an update whose color list is invalid and changes nothing" do
      palette = palettes(:brand)

      patch api_v1_palette_url(palette), as: :json, params: { palette: { colors: [
        { name: "bad", source_space: "rgb", r: -1, g: 0, b: 0 }
      ] } }

      assert_response :unprocessable_content
      assert_equal 3, palette.reload.colors.count
    end

    test "returns 404 when updating an unknown palette" do
      patch api_v1_palette_url("no-such-palette"), as: :json, params: { palette: { name: "x" } }

      assert_response :not_found
    end

    # --- Destroy -----------------------------------------------------------

    test "deletes a palette and leaves its colors behind" do
      assert_difference "Palette.count", -1 do
        assert_no_difference "Color.count" do
          delete api_v1_palette_url(palettes(:brand))
        end
      end

      assert_response :no_content
      assert_empty response.body
    end

    test "deletes a palette addressed by name" do
      id = palettes(:press).id

      delete api_v1_palette_url("Press Check")

      assert_response :no_content
      assert_not Palette.exists?(id)
    end

    test "returns 404 when deleting an unknown palette" do
      delete api_v1_palette_url("no-such-palette")

      assert_response :not_found
    end


    test "refuses a palette holding exactly another palette's colors" do
      assert_no_difference "Palette.count" do
        post api_v1_palettes_url, as: :json, params: { palette: {
          name: "Brand Core Copy",
          colors: palettes(:brand).color_ids.map { |id| { id: id } }
        } }
      end

      assert_response :unprocessable_content
      assert_includes json["errors"]["base"], %("Brand Core" already holds exactly these colors)
    end

    # --- Sorting ------------------------------------------------------------

    test "sorts palettes by the same orders the interface offers" do
      get api_v1_palettes_url(sort: "light")

      assert_equal [ "Press Check", "Brand Core", "Autumn 2026", "Unfilled" ],
        json.map { |palette| palette["name"] }
    end

    # The sequence of a palette's colors is the thing being published, so it
    # is what you get unless you ask for something else.
    test "a palette's colors keep their own order by default" do
      get colors_api_v1_palette_url(palettes(:brand))

      assert_equal [ "signal-red", "ink-black", "paper-white" ], json.map { |color| color["name"] }
    end

    test "a palette's colors can be asked for in another order" do
      get colors_api_v1_palette_url(palettes(:brand), sort: "light")

      assert_equal [ "paper-white", "signal-red", "ink-black" ], json.map { |color| color["name"] }
    end
  end
end
