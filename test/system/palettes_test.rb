require "application_system_test_case"

class PalettesTest < ApplicationSystemTestCase
  # --- Forking --------------------------------------------------------------
  #
  # A seasonal variant starts life as last season's palette with one colour
  # swapped, and the rule that no two palettes hold the same colours blocks
  # the clone that workflow would otherwise go through. So the fork carries
  # the swatches into the form instead of saving them: what you save is
  # already the palette you meant.

  test "starts a new palette from an existing one, with every swatch carried" do
    visit palette_path(palettes(:brand))
    click_on "New from this"

    assert_field "Name", with: "Brand Core copy"
    assert_selector ".carried-swatch", count: 3
    assert all(".carried-swatch input[type=checkbox]").all?(&:checked?),
      "the swatches come across ticked; the point is to change them, not re-pick them"
  end

  test "forks a palette with a swatch left behind" do
    visit new_palette_path(from: palettes(:brand).id)

    fill_in "Name", with: "Brand Lite"
    uncheck "ink-black"
    click_on "Create palette"

    # Text only the palette's own page carries: a path built from Palette
    # .find_by would be evaluated before the wait, when the row the request
    # is creating may not exist yet.
    assert_selector ".page-title", text: "Brand Lite"
    assert_equal [ "signal-red", "paper-white" ], Palette.find_by(name: "Brand Lite").colors.pluck(:name)
  end

  test "forks a palette with a swatch added and none dropped" do
    visit new_palette_path(from: palettes(:brand).id)

    fill_in "Name", with: "Brand Plus"
    choose "Hex"
    fill_in "Hex value", with: "#1E5AAA"
    fill_in "Swatch name", with: "brand-blue"
    click_on "Create palette"

    assert_selector ".page-title", text: "Brand Plus"
    assert_equal 4, Palette.find_by(name: "Brand Plus").colors.size
  end

  # Keeping everything and adding nothing is the duplicate the rule forbids,
  # and it says so in the same words it uses everywhere else.
  test "refuses a fork that changes nothing" do
    visit new_palette_path(from: palettes(:brand).id)

    fill_in "Name", with: "Brand Core Again"
    click_on "Create palette"

    assert_text %("Brand Core" already holds exactly these colours)
    assert_not Palette.exists?(name: "Brand Core Again")
  end

  test "a refused fork keeps the swatches you had chosen" do
    visit new_palette_path(from: palettes(:brand).id)

    fill_in "Name", with: ""
    uncheck "ink-black"
    click_on "Create palette"

    assert_text "Name can't be blank"
    assert_not find("#carried_#{colors(:ink_black).id}", visible: :all).checked?
    assert find("#carried_#{colors(:signal_red).id}", visible: :all).checked?
  end

  test "forking an empty palette carries nothing and still works" do
    visit new_palette_path(from: palettes(:empty).id)

    fill_in "Name", with: "Also Empty"
    click_on "Create palette"

    assert_selector ".page-title", text: "Also Empty"
    assert_text "No swatches yet"
  end

  test "a plain new palette offers no swatches to carry" do
    visit new_palette_path

    assert_no_selector ".carried-swatch"
    assert_empty find_field("Name").value.to_s
  end

  # --- Sorting ------------------------------------------------------------

  test "lists palettes by name until asked otherwise" do
    visit palettes_path

    assert_equal Palette.order(:name).pluck(:name), strip_names
    assert_selector "[data-filter=sort] .tag.active", text: "Name", exact_text: true
  end

  test "sorts palettes by colour, dark first and light first" do
    visit palettes_path

    sort_by "Dark first", leading: "Autumn 2026"
    sort_by "Light first", leading: "Press Check"
    sort_by "Colour", leading: "Brand Core"
  end

  test "an empty palette sorts last however the colours run" do
    visit palettes_path

    sort_by "Dark first", leading: "Autumn 2026"

    assert_equal "Unfilled", strip_names.last
  end

  test "sorts palettes by date added" do
    latest = Palette.create!(name: "Just Made")

    visit palettes_path
    sort_by "Date added", leading: latest.name
  end

  test "a palette order survives a tag filter" do
    visit palettes_path

    sort_by "Light first", leading: "Press Check"
    within("[data-filter=tag]") { click_on "active" }

    assert_selector ".palette-list > li", count: 2
    assert_equal [ "Brand Core", "Autumn 2026" ], strip_names
    assert_selector "[data-filter=sort] .tag.active", text: "Light first", exact_text: true
  end

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

    within("[data-filter=tag]") { click_on "seasonal" }

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
    choose "Hex"
    fill_in "Hex value", with: "not-a-colour"

    click_on "Create palette"

    assert_text "Hex is not a colour we can read"
    assert_no_text "Colors Hex"
    assert_equal "Half Filled", find_field("Name").value
    assert_not Palette.exists?(name: "Half Filled")
  end

  test "adds a swatch to an existing palette in cmyk" do
    visit palette_path(palettes(:press))
    click_on "Add a swatch"
    choose "New colour"

    fill_in "Swatch name", with: "process-magenta"
    choose "CMYK"
    fill_in "C", with: "0"
    fill_in "M", with: "100"
    fill_in "Y", with: "0"
    fill_in "K", with: "0"

    click_on "Add swatch"

    assert_current_path palette_path(palettes(:press))
    assert_text "process-magenta"
    assert_text "#FF00FF"
  end

  # --- Adding an existing swatch -----------------------------------------
  #
  # One colour row shared across palettes is the whole point of the join
  # table, so reaching for a colour already in the library leads — and a
  # library of near-identical swatches is what a "new colour" default builds.

  test "opens on the library" do
    visit new_palette_color_path(palettes(:press))

    assert find("#swatch_source_library", visible: :all).checked?
    assert_not find("#swatch_source_new", visible: :all).checked?
  end

  test "opens on the new colour form when there is nothing left to pick" do
    palette = palettes(:press)
    PaletteComposition.new(palette, attributes: {}, colors: Color.ids.map { |id| { id: id } }).save

    visit new_palette_color_path(palette)

    assert find("#swatch_source_new", visible: :all).checked?
    assert_not find("#swatch_source_library", visible: :all).checked?
  end

  test "comes back on the new colour form after it is refused" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: ""
    choose "Hex"
    fill_in "Hex value", with: "nope"
    click_on "Add swatch"

    # The refusal first: the radio is already checked before the submission,
    # so asserting on it alone would pass without the round trip happening.
    assert_text "is not a colour we can read"
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

  test "stays on the new colour form when it is rejected" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "impossible"
    choose "Hex"
    fill_in "Hex value", with: "not-a-colour"
    click_on "Add swatch"

    assert_text "is not a colour we can read"
    assert find("#swatch_source_new", visible: :all).checked?
  end

  test "leaves out colours the palette already holds" do
    visit new_palette_color_path(palettes(:brand), source: "library")

    assert_no_selector "#color_#{colors(:signal_red).id}"
    assert_no_selector "#color_#{colors(:ink_black).id}"
    assert_selector "#color_#{colors(:deep_indigo).id}"
  end

  test "adds an existing colour without making a second copy of it" do
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

  test "an added colour keeps its place in the palettes it already belonged to" do
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

  test "still offers a new colour alongside the library" do
    visit new_palette_color_path(palettes(:press), source: "new")

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
    choose "New colour"

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
    fill_in "Hex value", with: "not-a-colour"

    click_on "Add swatch"

    assert_text "is not a colour we can read"
  end

  test "adds a swatch chosen with the system picker" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "picked"
    choose "Picker"
    fill_in "Pick a colour", with: "#1e5aaa"

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

  test "records a hex entered colour as an rgb source" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "Swatch name", with: "hex sourced"
    choose "Hex"
    fill_in "Hex value", with: "#D5162B"
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

    assert_selector ".swatch-grid > li:first-child .swatch-name", text: "ink-black"
    assert_equal [ "ink-black", "signal-red", "paper-white" ], all(".swatch-detail .swatch-name").map(&:text)
    assert_equal [ "ink-black", "signal-red", "paper-white" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "moves a swatch earlier in the palette" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_paper_white).id}" do
      click_on "Up"
    end

    assert_selector ".swatch-grid > li:nth-child(2) .swatch-name", text: "paper-white"
    assert_equal [ "signal-red", "paper-white", "ink-black" ], all(".swatch-detail .swatch-name").map(&:text)
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

    assert_selector ".swatch-grid > li:first-child .swatch-name", text: "ink-black"
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

  test "asks before deleting a palette" do
    visit palette_path(palettes(:press))

    assert_equal "Delete Press Check and its swatch order? The colours stay in the library.",
      find("button", text: "Delete palette")[:"data-turbo-confirm"]
  end

  test "deletes a palette" do
    visit palette_path(palettes(:press))

    confirming { click_on "Delete palette" }

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

  # --- Duplicates --------------------------------------------------------

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

  test "refuses a palette that would hold exactly another palette's colours" do
    palettes(:brand).colors.each do |color|
      visit new_palette_color_path(palettes(:empty), source: "library")
      within "#color_#{color.id}" do
        click_on "Add"
      end
    end

    assert_text %("Brand Core" already holds exactly these colours)
    assert_equal 2, palettes(:empty).palette_colors.reload.size,
      "the swatch that would have completed the duplicate must not have landed"
  end

  test "refuses to remove a swatch that would leave a duplicate palette" do
    press = palettes(:press)
    PaletteComposition.new(press, attributes: {},
      colors: palettes(:brand).color_ids.map { |id| { id: id } } + [ { id: colors(:process_cyan).id } ]).save

    visit palette_path(press)

    within "#palette_color_#{press.palette_colors.find_by(color: colors(:process_cyan)).id}" do
      click_on "Remove"
    end

    assert_text %("Brand Core" already holds exactly these colours)
    assert_equal 4, press.palette_colors.reload.size
  end


  private
    # Choosing an order is a whole navigation, so this waits for the reordered
    # list before handing back: reading the strips does not retry.
    def sort_by(label, leading:)
      within("[data-filter=sort]") { click_on label }

      assert_selector ".palette-list > li:first-child .palette-strip__name",
        text: leading, exact_text: true
    end

    # Reading a collection is two steps — find the nodes, then ask each for its
    # text — and a view transition can swap them in between. synchronize is
    # Capybara's own answer to that: it retries the block on a stale node, and
    # runs it once under rack_test, where nothing moves.
    def strip_names
      page.document.synchronize do
        all(".palette-list .palette-strip__name", minimum: 1).map(&:text)
      end
    end
end
