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

  test "counts the whole library when nothing is filtered" do
    visit palettes_path

    assert_text "4 palettes in the library"
  end

  test "counts the matches, not the library, when filtered" do
    visit palettes_path

    fill_in "Search", with: "autumn"
    click_on "Filter"

    assert_text "1 of 4 palettes"
    assert_no_text "1 palette in the library"
  end

  test "the count sits inside the frame the search replaces" do
    visit palettes_path

    within "turbo-frame#palettes" do
      assert_text "4 palettes in the library"
    end
  end

  test "creating a palette is an action on the page, not a filter control" do
    visit palettes_path

    assert_selector ".page-head", text: "New palette"
    assert_no_selector ".filters", text: "New palette"
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

  test "a swatch card is one link, not two to the same place" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      assert_selector "a", count: 1
    end
  end

  test "an empty library reads as empty, not as a failed search" do
    Palette.destroy_all

    visit palettes_path

    assert_text "No palettes yet"
    assert_no_text "No palettes match"
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

  # --- Adding an existing swatch -----------------------------------------
  #
  # One colour row shared across palettes is the whole point of the join
  # table, so reaching for a colour already in the library has to be at least
  # as easy as typing a new one.

  test "opens on the new colour form" do
    visit new_palette_color_path(palettes(:press))

    assert find("#swatch_source_new", visible: :all).checked?
    assert_not find("#swatch_source_library", visible: :all).checked?
  end

  test "offers a switch to the existing library" do
    visit new_palette_color_path(palettes(:press))

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

  test "stays on the new colour form when it is rejected" do
    visit new_palette_color_path(palettes(:press))

    fill_in "Swatch name", with: "impossible"
    fill_in "R", with: "999"
    click_on "Add swatch"

    assert_text "must be less than or equal to 255"
    assert find("#swatch_source_new", visible: :all).checked?
  end

  test "leaves out colours the palette already holds" do
    visit new_palette_color_path(palettes(:brand))

    assert_no_selector "#color_#{colors(:signal_red).id}"
    assert_no_selector "#color_#{colors(:ink_black).id}"
    assert_selector "#color_#{colors(:deep_indigo).id}"
  end

  test "adds an existing colour without making a second copy of it" do
    assert_no_difference "Color.count" do
      assert_difference "PaletteColor.count", 1 do
        visit new_palette_color_path(palettes(:press))

        within "#color_#{colors(:signal_red).id}" do
          click_on "Add"
        end
      end
    end

    assert_text "signal-red"
    assert_equal [ "process-cyan", "signal-red" ], palettes(:press).reload.colors.map(&:name)
  end

  test "an added colour keeps its place in the palettes it already belonged to" do
    visit new_palette_color_path(palettes(:press))

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

    visit new_palette_color_path(palette)

    assert_text "already in this palette"
  end

  test "still offers a new colour alongside the library" do
    visit new_palette_color_path(palettes(:press))

    assert_text "New colour"
    assert_selector "#swatch_name"
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

  test "moves a swatch later in the palette" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      click_on "Down"
    end

    assert_equal [ "ink-black", "signal-red", "paper-white" ], palettes(:brand).reload.colors.map(&:name)
    assert_equal [ "ink-black", "signal-red", "paper-white" ], all(".swatch-detail .swatch-name").map(&:text)
  end

  test "moves a swatch earlier in the palette" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_paper_white).id}" do
      click_on "Up"
    end

    assert_equal [ "signal-red", "paper-white", "ink-black" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "offers no way to move the first swatch up or the last one down" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      assert_no_selector "button", text: "Up"
      assert_selector "button", text: "Down"
    end

    within "#palette_color_#{palette_colors(:brand_paper_white).id}" do
      assert_selector "button", text: "Up"
      assert_no_selector "button", text: "Down"
    end
  end

  test "moving a swatch leaves the other palettes holding it alone" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      click_on "Down"
    end

    assert_equal [ "autumn-ochre", "signal-red" ], palettes(:autumn).reload.colors.map(&:name)
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
