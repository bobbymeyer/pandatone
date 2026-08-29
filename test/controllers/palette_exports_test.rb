require "test_helper"

# The same two files, reachable both ways: a person clicks a link on the
# palette page, a script asks the API for it. Anything the interface can do,
# the API can do.
class PaletteExportsTest < ActionDispatch::IntegrationTest
  test "the interface serves an ASE download to a signed in person" do
    sign_in_as users(:keeper)

    get palette_path(palettes(:brand), format: :ase)

    assert_response :success
    assert_equal "application/x-adobe-ase", response.media_type
    assert_equal "ASEF", response.body[0, 4]
    assert_match(/attachment; filename="brand-core\.ase"/, response.headers["Content-Disposition"])
  end

  test "the interface serves custom properties to a signed in person" do
    sign_in_as users(:keeper)

    get palette_path(palettes(:brand), format: :css)

    assert_response :success
    assert_equal "text/css", response.media_type
    assert_includes response.body, "--signal-red: #E30613;"
    assert_match(/attachment; filename="brand-core\.css"/, response.headers["Content-Disposition"])
  end

  test "the API serves the same two files to a script" do
    sign_in_client

    get api_v1_palette_url(palettes(:brand), format: :ase)
    assert_equal "ASEF", response.body[0, 4]

    get api_v1_palette_url(palettes(:brand), format: :css)
    assert_includes response.body, "--signal-red: #E30613;"
  end

  # A palette is addressable by name over the API, and an export is no
  # different: asking for "Brand Core.ase" should not need an id lookup first.
  test "the API takes a palette name as readily as an id" do
    sign_in_client

    get api_v1_palette_url("Brand Core", format: :ase)

    assert_response :success
    assert_equal "ASEF", response.body[0, 4]
  end

  # Adding formats to this endpoint is how it briefly stopped answering at all
  # without one: respond_to matches the request format, and a request that
  # names none is HTML by default. The API published itself as JSON from the
  # first commit and asking for it plainly has to keep meaning that.
  test "no extension still means JSON" do
    sign_in_client

    get api_v1_palette_url(palettes(:brand))

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "Brand Core", json["name"]
  end

  test "an export is behind the same door as everything else" do
    get palette_path(palettes(:brand), format: :ase)
    assert_redirected_to new_session_path

    get api_v1_palette_url(palettes(:brand), format: :css)
    assert_response :unauthorized
  end

  test "asking for a palette that is not there is still a 404" do
    sign_in_client

    get api_v1_palette_url("no-such-palette", format: :ase)

    assert_response :not_found
  end
end
