require "application_system_test_case"

class AddSwatchTest < ApplicationSystemTestCase
  # Putting a swatch in a palette: picking one the library already holds,
  # or entering a new color in whichever space it came to you in.
  #
  # One color row shared across palettes is the whole point of the join
  # table, so reaching for a color already in the library leads — and a
  # library of near-identical swatches is what a "new color" default builds.

  test "opens on the library" do
    visit new_palette_color_path(palettes(:press))

    assert find("#swatch_source_library", visible: :all).checked?
    assert_not find("#swatch_source_new", visible: :all).checked?
  end

  test "opens on the new color form when there is nothing left to pick" do
    palette = palettes(:press)
    PaletteComposition.new(palette, attributes: {}, colors: Color.ids.map { |id| { id: id } }).save

    visit new_palette_color_path(palette)

    assert find("#swatch_source_new", visible: :all).checked?
    assert_not find("#swatch_source_library", visible: :all).checked?
  end

  test "comes back on the new color form after it is refused" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: ""
    choose "Hex"
    fill_in "Hex value", with: "nope"
    click_on "Add swatch"

    # The refusal first: the radio is already checked before the submission,
    # so asserting on it alone would pass without the round trip happening.
    assert_text "is not a color we can read"
    assert find("#swatch_source_new", visible: :all).checked?
  end

  test "offers a switch to the existing library" do
    visit new_palette_color_path(palettes(:press), source: "library")

    assert_text "Existing swatch"
    assert_selector "#color_#{colors(:signal_red).id}"
    assert_selector "#color_#{colors(:deep_indigo).id}"
  end

  test "opens on the library when asked for it" do
    visit new_palette_color_path(palettes(:press), source: "library")

    assert find("#swatch_source_library", visible: :all).checked?
    assert_not find("#swatch_source_new", visible: :all).checked?
  end

  test "stays on the library after searching it" do
    visit new_palette_color_path(palettes(:press), source: "library")

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert find("#swatch_source_library", visible: :all).checked?
  end

  test "stays on the new color form when it is rejected" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "impossible"
    choose "Hex"
    fill_in "Hex value", with: "not-a-color"
    click_on "Add swatch"

    assert_text "is not a color we can read"
    assert find("#swatch_source_new", visible: :all).checked?
  end

  test "leaves out colors the palette already holds" do
    visit new_palette_color_path(palettes(:brand), source: "library")

    assert_no_selector "#color_#{colors(:signal_red).id}"
    assert_no_selector "#color_#{colors(:ink_black).id}"
    assert_selector "#color_#{colors(:deep_indigo).id}"
  end

  test "adds an existing color without making a second copy of it" do
    visit new_palette_color_path(palettes(:press), source: "library")
    colors_before, memberships_before = Color.count, PaletteColor.count

    within "#color_#{colors(:signal_red).id}" do
      click_on "Add"
    end

    # Wait for the palette page before reading the records: in a browser the
    # click returns as soon as it is dispatched.
    assert_selector ".swatch-grid"
    assert_text "signal-red"

    assert_equal colors_before, Color.count
    assert_equal memberships_before + 1, PaletteColor.count
    assert_equal [ "process-cyan", "signal-red" ], palettes(:press).reload.colors.map(&:name)
  end

  test "an added color keeps its place in the palettes it already belonged to" do
    visit new_palette_color_path(palettes(:press), source: "library")

    within "#color_#{colors(:signal_red).id}" do
      click_on "Add"
    end

    assert_equal [ "signal-red", "ink-black", "paper-white" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "shows the swatches already in the palette as one row at the top" do
    visit new_palette_color_path(palettes(:brand))

    within ".current-swatches" do
      assert_selector ".swatch", count: 3
      assert_selector ".swatch[style*='#E30613']"
      assert_selector ".swatch[style*='#111111']"
    end
  end

  test "leaves out the current row for a palette with no swatches" do
    visit new_palette_color_path(palettes(:empty))

    assert_no_selector ".current-swatches"
  end

  test "offers the library to choose from as a grid below" do
    visit new_palette_color_path(palettes(:press), source: "library")

    assert_selector ".library-picker .color-list"
    assert_equal 5, all(".library-picker .color-list > .color-card").size
  end

  test "searches the library when adding a swatch" do
    visit new_palette_color_path(palettes(:press), source: "library")

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_selector "#color_#{colors(:ink_black).id}"
    assert_no_selector "#color_#{colors(:signal_red).id}"
  end

  test "says so when the library has nothing left to offer" do
    palette = Palette.create!(name: "Everything")
    Color.find_each { |color| palette.palette_colors.create!(color: color) }

    visit new_palette_color_path(palette, source: "library")

    assert_text "already in this palette"
  end

  test "still offers a new color alongside the library" do
    visit new_palette_color_path(palettes(:press), source: "new")

    assert_text "New color"
    assert_selector "#swatch_name"
  end

  test "offers all four ways of entering a color" do
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
    choose "New color"

    fill_in "Swatch name", with: "signal-blue"
    choose "Hex"
    fill_in "Hex value", with: "#1E5AAA"

    before = Color.count
    click_on "Add swatch"

    assert_current_path palette_path(palettes(:press))
    assert_text "signal-blue"
    assert_text "#1E5AAA"
    assert_equal before + 1, Color.count
  end

  test "accepts hex without a leading hash" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "shorthand"
    choose "Hex"
    fill_in "Hex value", with: "fc0"

    click_on "Add swatch"

    assert_current_path palette_path(palettes(:press))
    assert_text "#FFCC00"
  end

  test "reports a hex it cannot read" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "nonsense"
    choose "Hex"
    fill_in "Hex value", with: "not-a-color"

    click_on "Add swatch"

    assert_text "is not a color we can read"
  end

  test "adds a swatch chosen with the system picker" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "picked"
    choose "Picker"
    fill_in "Pick a color", with: "#1e5aaa"

    click_on "Add swatch"

    assert_current_path palette_path(palettes(:press))
    assert_text "picked"
    assert_text "#1E5AAA"
  end

  test "ignores the fields of the spaces not chosen" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "hex wins"
    fill_in "R", with: "1"
    fill_in "G", with: "2"
    fill_in "B", with: "3"
    choose "Hex"
    fill_in "Hex value", with: "#D5162B"

    before = Color.count
    click_on "Add swatch"

    assert_current_path palette_path(palettes(:press))
    assert_text "#D5162B"
    assert_no_text "#010203"
    assert_equal before + 1, Color.count
  end

  test "still leaves an untouched entry row alone even though the picker always has a value" do
    visit new_palette_path

    fill_in "Name", with: "Untouched Row"
    click_on "Create palette"

    assert_text "Untouched Row"
    assert_text "No swatches"
  end

  test "records a hex entered color as an rgb source" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "hex sourced"
    choose "Hex"
    fill_in "Hex value", with: "#D5162B"
    click_on "Add swatch"

    click_on "hex sourced"
    assert_text "Authored in RGB"
  end

  test "asks before adding a new swatch that is nearly one in the library" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "off-white"
    choose "Hex"
    fill_in "Hex value", with: "#FFFFFF"

    before = Color.count
    click_on "Add swatch"

    assert_text "This is similar to paper-white"
    assert_equal before, Color.count

    click_on "Add anyway"

    assert_current_path palette_path(palettes(:press))
    assert_text "off-white"
    assert_equal before + 1, Color.count
  end

  test "says nothing about a swatch picked out of the library" do
    visit new_palette_color_path(palettes(:press), source: "library")

    within "#color_#{colors(:paper_white).id}" do
      click_on "Add"
    end

    assert_no_text "This is similar to"
    assert_text "paper-white"
  end
end
