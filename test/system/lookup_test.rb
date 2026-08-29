require "application_system_test_case"

class LookupTest < ApplicationSystemTestCase
  # Asking the library about a color you have in hand: what it reads, what
  # it holds, and the nearest thing it has when it holds nothing.

  test "looks a color up by hex and lists every palette containing it" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "looks a color up by hex without a leading hash" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "e30613"
    click_on "Look up"

    assert_text "Brand Core"
  end

  test "looks a color up by an rgb triple" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "227, 6, 19"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
  end

  # Every color stores both spaces, so a search in one finds a color
  # authored in the other. process-cyan was authored in CMYK; signal-red in
  # RGB. Each is findable from either direction.
  test "finds a cmyk authored color from its build" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "100, 0, 0, 0"
    click_on "Look up"

    assert_text "process-cyan"
    assert_text "Press Check"
    assert_text "Read as a CMYK build"
  end

  test "finds a cmyk authored color from its hex" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#00FFFF"
    click_on "Look up"

    assert_text "process-cyan"
    assert_no_text "Read as a CMYK build"
  end

  test "finds an rgb authored color from a cmyk build" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "0, 97.4, 91.6, 11"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
  end

  test "reads three numbers as rgb and four as a build" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "0, 255, 255"
    click_on "Look up"

    assert_text "process-cyan"
    assert_no_text "Read as a CMYK build"
  end

  test "reports a build outside the ink range" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "0, 0, 0, 140"
    click_on "Look up"

    assert_text "Could not read"
  end

  test "shows the swatch even when no stored color matches" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_selector ".swatch[style*='#ABCDEF']"
    assert_text "Not in the library"
  end

  # "We do not have that" on its own sends you away to look somewhere else.
  # The nearest thing on file is usually the answer you were after — and if it
  # is not, the color you just pasted is one click from joining the library.
  test "offers to add a color the library does not hold" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_text "Not in the library"
    click_on "Add this color swatch"

    assert_current_path(/#{Regexp.escape(new_color_path)}/)
    assert_equal "#ABCDEF", find_field("Hex value").value
    assert find("#swatch_input_mode_hex", visible: :all).checked?
  end

  test "adding from a lookup lands the color in the library" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"
    click_on "Add this color swatch"

    fill_in "Swatch name", with: "sky"

    before = Color.count
    click_on "Create color"

    assert_text "No palettes hold this color yet"
    assert_text "#ABCDEF"
    assert_equal before + 1, Color.count
    assert_equal [ 171, 205, 239 ], Color.find_by(name: "sky").rgb.values
  end

  test "does not offer to add a color the library already holds" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_no_link "Add this color swatch"
  end

  test "offers the closest stored color when the library holds no match" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#FFFFFF"
    click_on "Look up"

    assert_text "Not in the library"
    within ".lookup-nearest" do
      assert_text "paper-white"
      assert_text "#FAFAF8"
      assert_selector ".swatch[style*='#FAFAF8']"
    end
  end

  test "the closest stored color links through to it" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#FFFFFF"
    click_on "Look up"

    within(".lookup-nearest") { click_on "paper-white" }

    assert_current_path color_path(colors(:paper_white))
  end

  test "offers a closest color however far off it is" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#800080"
    click_on "Look up"

    assert_selector ".lookup-nearest .swatch"
  end

  test "does not offer a closest color when the lookup matched exactly" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_no_selector ".lookup-nearest"
  end

  test "says nothing about a closest color when the library is empty" do
    PaletteColor.delete_all
    Color.delete_all

    visit lookup_path
    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_text "Not in the library"
    assert_no_selector ".lookup-nearest"
  end

  # The one navigation on this screen is to the color it found, so the swatch
  # takes that color's transition name and morphs across rather than fading.
  test "a found color keeps its transition name through to its page" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    swatch = find(".lookup-result > .swatch")
    assert_match(/view-transition-name:\s*color-#{colors(:signal_red).id}\b/, swatch[:style])
  end

  test "an unmatched lookup names its swatch by the color itself" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    swatch = find(".lookup-result > .swatch")
    assert_match(/view-transition-name:\s*lookup-ABCDEF\b/, swatch[:style])
  end

  test "reports an unreadable lookup" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "wat"
    click_on "Look up"

    assert_text "Could not read"
  end

  test "a row of a form does not stretch across the page" do
    needs_a_browser

    visit lookup_path

    # An unbounded row put the field across the whole width and stranded the
    # button against the right edge.
    assert width_of(".form--inline") <= width_of(".page-head"),
      "the inline form is wider than the text column it sits under"
  end
end
