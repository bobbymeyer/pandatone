require "application_system_test_case"

class PalettesTest < ApplicationSystemTestCase
  test "lists palettes as strips of their swatches" do
    visit palettes_path

    assert_text "Brand Core"
    assert_text "Autumn 2026"

    within "#palette_#{palettes(:brand).id}" do
      assert_selector ".swatch", count: 3
      assert_selector ".swatch[style*='#E30613']"
    end
  end

  test "shows a palette with no swatches without breaking" do
    visit palettes_path

    within "#palette_#{palettes(:empty).id}" do
      assert_text "Unfilled"
      assert_no_selector ".swatch"
    end
  end

  test "filters the index by tag" do
    visit palettes_path

    click_on "seasonal"

    assert_text "Autumn 2026"
    assert_no_text "Brand Core"
  end

  test "searches the index by name" do
    visit palettes_path

    fill_in "Search", with: "autumn"
    click_on "Filter"

    assert_text "Autumn 2026"
    assert_no_text "Press Check"
  end

  test "says so when a search matches nothing" do
    visit palettes_path

    fill_in "Search", with: "nothing-matches-this"
    click_on "Filter"

    assert_text "No palettes"
  end

  test "shows a palette with every swatch in both colour spaces" do
    visit palette_path(palettes(:brand))

    assert_text "Brand Core"

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      assert_text "signal-red"
      assert_text "#E30613"
      assert_text "227"       # rgb
      assert_text "97.4"      # cmyk
    end
  end

  test "creates a palette with a first swatch in one pass" do
    visit palettes_path
    click_on "New palette"

    fill_in "Name", with: "Winter 2027"
    fill_in "Tags", with: "Seasonal, cool"

    fill_in "Swatch name", with: "frost"
    fill_in "R", with: "200"
    fill_in "G", with: "220"
    fill_in "B", with: "255"

    click_on "Create palette"

    assert_text "Winter 2027"
    assert_text "seasonal"
    assert_text "frost"
    assert_text "#C8DCFF"
  end

  test "creates a palette without a swatch" do
    visit new_palette_path

    fill_in "Name", with: "Later"
    click_on "Create palette"

    assert_text "Later"
    assert_text "No swatches"
  end

  test "reports validation errors when creating a palette" do
    visit new_palette_path

    fill_in "Name", with: ""
    click_on "Create palette"

    assert_text "can't be blank"
  end

  test "reports validation errors from the swatch without losing the palette name" do
    visit new_palette_path

    fill_in "Name", with: "Half Filled"
    fill_in "Swatch name", with: "impossible"
    fill_in "R", with: "999"

    click_on "Create palette"

    assert_text "must be less than or equal to 255"
    assert_equal "Half Filled", find_field("Name").value
    assert_not Palette.exists?(name: "Half Filled")
  end

  test "adds a swatch to an existing palette in cmyk" do
    visit palette_path(palettes(:press))
    click_on "Add a swatch"

    fill_in "Swatch name", with: "process-magenta"
    choose "CMYK"
    fill_in "C", with: "0"
    fill_in "M", with: "100"
    fill_in "Y", with: "0"
    fill_in "K", with: "0"

    click_on "Add swatch"

    assert_text "process-magenta"
    assert_text "#FF00FF"
  end

  test "offers all four ways of entering a colour" do
    visit new_palette_color_path(palettes(:press))

    assert_selector "input[type=radio][value=rgb]", visible: :all
    assert_selector "input[type=radio][value=cmyk]", visible: :all
    assert_selector "input[type=radio][value=hex]", visible: :all
    assert_selector "input[type=radio][value=picker]", visible: :all
    assert_selector "input[type=color]", visible: :all
  end

  test "starts on rgb" do
    visit new_palette_color_path(palettes(:press))

    assert find("#swatch_input_mode_rgb", visible: :all).checked?
  end

  test "adds a swatch entered as hex" do
    visit palette_path(palettes(:press))
    click_on "Add a swatch"

    fill_in "Swatch name", with: "signal-red"
    choose "Hex"
    fill_in "Hex value", with: "#E30613"

    click_on "Add swatch"

    assert_text "signal-red"
    assert_text "#E30613"
  end

  test "accepts hex without a leading hash" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "shorthand"
    choose "Hex"
    fill_in "Hex value", with: "fc0"

    click_on "Add swatch"

    assert_text "#FFCC00"
  end

  test "reports a hex it cannot read" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "nonsense"
    choose "Hex"
    fill_in "Hex value", with: "not-a-colour"

    click_on "Add swatch"

    assert_text "is not a colour we can read"
  end

  test "adds a swatch chosen with the system picker" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "picked"
    choose "Picker"
    fill_in "Pick a colour", with: "#2b4a8a"

    click_on "Add swatch"

    assert_text "picked"
    assert_text "#2B4A8A"
  end

  test "ignores the fields of the spaces not chosen" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "hex wins"
    fill_in "R", with: "1"
    fill_in "G", with: "2"
    fill_in "B", with: "3"
    choose "Hex"
    fill_in "Hex value", with: "#E30613"

    click_on "Add swatch"

    assert_text "#E30613"
    assert_no_text "#010203"
  end

  test "still leaves an untouched entry row alone even though the picker always has a value" do
    visit new_palette_path

    fill_in "Name", with: "Untouched Row"
    click_on "Create palette"

    assert_text "Untouched Row"
    assert_text "No swatches"
  end

  test "records a hex entered colour as an rgb source" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "hex sourced"
    choose "Hex"
    fill_in "Hex value", with: "#E30613"
    click_on "Add swatch"

    click_on "hex sourced"
    assert_text "Authored in RGB"
  end

  test "removes a swatch from a palette but keeps the colour in the library" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_ink_black).id}" do
      click_on "Remove"
    end

    assert_no_text "ink-black"
    assert Color.exists?(colors(:ink_black).id)
  end

  test "reorders the swatches in a palette" do
    visit palette_path(palettes(:brand))

    fill_in "position_#{palette_colors(:brand_paper_white).id}", with: "0"
    fill_in "position_#{palette_colors(:brand_signal_red).id}", with: "1"
    fill_in "position_#{palette_colors(:brand_ink_black).id}", with: "2"

    click_on "Save order"

    assert_equal [ "paper-white", "signal-red", "ink-black" ], palettes(:brand).reload.colors.map(&:name)
    assert_equal [ "paper-white", "signal-red", "ink-black" ], all(".swatch-detail .swatch-name").map(&:text)
  end

  test "edits palette tags inline" do
    visit palette_path(palettes(:press))

    click_on "Edit tags"
    fill_in "Tags", with: "print, archive"
    click_on "Save tags"

    assert_text "archive"
  end

  test "edits a palette name" do
    visit palette_path(palettes(:press))
    click_on "Edit palette"

    fill_in "Name", with: "Press Check 2027"
    click_on "Save palette"

    assert_text "Press Check 2027"
  end

  test "deletes a palette" do
    visit palette_path(palettes(:press))

    click_on "Delete palette"

    assert_text "Palettes"
    assert_no_text "Press Check"
    assert Color.exists?(colors(:process_cyan).id)
  end

  test "navigates from a swatch on the index through to the colour" do
    visit palettes_path

    within "#palette_#{palettes(:brand).id}" do
      click_on "Brand Core"
    end

    click_on "signal-red"

    assert_text "signal-red"
    assert_text "#E30613"
  end
end
