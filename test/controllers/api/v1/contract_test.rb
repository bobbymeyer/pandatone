require "test_helper"

# GET /api/v1/palettes/:id/colors is the endpoint other tools build against.
# This test snapshots its exact JSON. If it fails, a downstream consumer
# breaks, so treat a change here as a version bump rather than a fix.
class Api::V1::ContractTest < ActionDispatch::IntegrationTest
  test "the palette colours endpoint returns exactly this shape" do
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

  test "colour keys appear in a stable order" do
    get colors_api_v1_palette_url("Brand Core")

    JSON.parse(response.body).each do |color|
      assert_equal %w[ id name hex rgb cmyk source_space tags ], color.keys
      assert_equal %w[ r g b ], color["rgb"].keys
      assert_equal %w[ c m y k ], color["cmyk"].keys
    end
  end

  test "the two documented consumer questions are answerable in one call each" do
    # "Give me the colours of the palette tagged active."
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
end
