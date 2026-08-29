require "application_system_test_case"

class ColorsTest < ApplicationSystemTestCase
  # --- Index -------------------------------------------------------------

  test "lists every colour in the library as a swatch" do
    visit colors_path

    assert_selector ".color-card", count: 6

    within "#color_#{colors(:signal_red).id}" do
      assert_text "signal-red"
      assert_text "#E30613"
      assert_selector ".swatch[style*='#E30613']"
    end
  end

  test "shows on the index which palettes each colour sits in" do
    visit colors_path

    within "#color_#{colors(:signal_red).id}" do
      assert_text "Brand Core"
      assert_text "Autumn 2026"
    end
  end

  test "says on the index when a colour sits in no palette" do
    visit colors_path

    within "#color_#{colors(:deep_indigo).id}" do
      assert_text "No palettes"
    end
  end

  test "counts the matches, not the library, when filtered" do
    visit colors_path

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_text "1 of 6 colours"
  end

  test "filters the colour index by tag" do
    visit colors_path

    within("[data-filter=tag]") { click_on "print" }

    assert_text "process-cyan"
    assert_no_text "signal-red"
  end

  test "searches the colour index by name" do
    visit colors_path

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_text "ink-black"
    assert_no_text "signal-red"
  end

  test "says so when the colour search matches nothing" do
    visit colors_path

    fill_in "Search", with: "nothing-matches-this"
    click_on "Filter"

    assert_text "No colours"
  end

  test "reaches a colour from the index" do
    visit colors_path

    within "#color_#{colors(:autumn_ochre).id}" do
      click_on "autumn-ochre"
    end

    assert_text "#C4842C"
    assert_text "Autumn 2026"
  end

  test "combines the colour tag filter with a search" do
    visit colors_path

    within("[data-filter=tag]") { click_on "brand" }
    assert_text "3 of 6 colours"

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_text "ink-black"
    assert_no_text "paper-white"
  end

  test "a colour card is one link to the colour, not two to the same place" do
    visit colors_path

    within "#color_#{colors(:signal_red).id}" do
      # href comes back absolute in a browser and raw under rack_test.
      paths = all("a").map { |link| URI.parse(link[:href]).path }
      assert_equal 1, paths.count("/colors/#{colors(:signal_red).id}"),
        "the swatch and the name are one link between them, not two"
    end
  end

  # Tags on a card look like the tags in the filter bar because they are the
  # same thing, so they behave like them rather than being inert text wearing
  # a control's clothes.
  test "a card's tags filter the library" do
    visit colors_path

    within("#color_#{colors(:signal_red).id}") { click_on "primary" }

    assert_selector "[data-filter=tag] .tag.active", text: "primary", exact_text: true
    assert_equal [ "signal-red" ], card_names
  end

  test "an empty library reads as empty, not as a failed search" do
    Palette.destroy_all
    Color.destroy_all

    visit colors_path

    assert_text "No colours yet"
    assert_no_text "No colours match"
  end

  test "an empty result reads as a failed search" do
    visit colors_path

    fill_in "Search", with: "nothing-matches-this"
    click_on "Filter"

    assert_text "No colours match"
    assert_no_text "No colours yet"
  end

  # --- Tags and copying ----------------------------------------------------

  test "edits a colour's tags in place" do
    visit color_path(colors(:deep_indigo))

    click_on "Edit tags"
    fill_in "Tags", with: "Cool, brand"
    click_on "Save tags"

    assert_current_path color_path(colors(:deep_indigo))
    assert_text "cool · brand"
  end

  test "says so rather than showing nothing when a colour has no tags" do
    colors(:deep_indigo).update!(tags: [])

    visit color_path(colors(:deep_indigo))

    assert_text "Untagged"
  end

  # A hex is on screen to be taken somewhere else, so it is a button. The
  # value stays readable inside it, which is what keeps the page usable when
  # the clipboard is not.
  test "every hex on screen is a copy button carrying its own value" do
    visit color_path(colors(:signal_red))

    button = find(".hex--copy", match: :first)
    assert_equal "#E30613", button.text
    assert_equal "#E30613", button["data-clipboard-text-value"]
    assert_equal "Copy #E30613", button["aria-label"]
  end

  test "hexes are copy buttons on the index and the lookup too" do
    visit colors_path
    assert_selector ".color-card .hex--copy", minimum: 6

    visit lookup_path(q: "#E30613")
    assert_selector ".hex--copy", text: "#E30613"
  end

  # --- Deleting -----------------------------------------------------------

  test "deletes a colour no palette holds" do
    visit color_path(colors(:deep_indigo))

    confirming { click_on "Delete colour" }

    assert_current_path colors_path
    assert_no_text "deep-indigo"
    assert_not Color.exists?(colors(:deep_indigo).id)
  end

  # The confirmation is the last place to say what deleting a shared colour
  # will actually do, so it names the palettes rather than asking twice.
  test "names the palettes before deleting a colour they hold" do
    visit color_path(colors(:signal_red))

    assert_equal "signal-red is in Autumn 2026 and Brand Core. Delete it and take it out of those palettes?",
      find_button("Delete colour")[:"data-turbo-confirm"]
  end

  test "deletes a shared colour out of every palette holding it" do
    visit color_path(colors(:signal_red))

    confirming { click_on "Delete colour" }

    assert_current_path colors_path
    assert_equal [ "ink-black", "paper-white" ], palettes(:brand).colors.reload.order(:name).pluck(:name)
  end

  test "refuses a deletion that would leave two palettes identical" do
    pair = Palette.new
    PaletteComposition.new(pair, attributes: { name: "Pair" },
      colors: [ { id: colors(:signal_red).id }, { id: colors(:ink_black).id } ]).save

    visit color_path(colors(:paper_white))
    confirming { click_on "Delete colour" }

    assert_text %(Deleting this would leave "Brand Core" and "Pair" holding exactly the same colours)
    assert Color.exists?(colors(:paper_white).id)
  end

  # --- Sorting ------------------------------------------------------------

  test "lists colours by name until asked otherwise" do
    visit colors_path

    assert_equal Color.order(:name).pluck(:name), card_names
    assert_selector "[data-filter=sort] .tag.active", text: "Name", exact_text: true
  end

  test "sorts by colour, dark first and light first" do
    visit colors_path

    sort_by "Dark first", leading: "ink-black"
    sort_by "Light first", leading: "paper-white"
    sort_by "Colour", leading: "ink-black"

    assert_equal "paper-white", card_names.last, "the lightest neutral closes the spectrum"
  end

  test "sorts by date added and date modified" do
    latest = Color.create!(name: "brand new", source_space: "rgb", r: 3, g: 200, b: 90)
    colors(:autumn_ochre).update!(tags: [ "seasonal", "warm" ])

    visit colors_path

    sort_by "Date added", leading: latest.name
    sort_by "Date modified", leading: "autumn-ochre"
  end

  test "a sort survives a tag filter" do
    visit colors_path

    sort_by "Dark first", leading: "ink-black"
    within("[data-filter=tag]") { click_on "brand" }

    assert_selector ".color-list > li", count: 3
    assert_equal [ "ink-black", "signal-red", "paper-white" ], card_names
    assert_selector "[data-filter=sort] .tag.active", text: "Dark first", exact_text: true
  end

  test "a search keeps the sort it was run under" do
    visit colors_path

    sort_by "Light first", leading: "paper-white"
    fill_in "Search", with: "process"
    filter_unless_live

    assert_selector ".color-list > li", count: 1
    assert_equal [ "process-cyan" ], card_names
    assert_selector "[data-filter=sort] .tag.active", text: "Light first", exact_text: true
  end

  test "creates a colour that belongs to no palette yet" do
    visit colors_path
    click_on "New colour"

    fill_in "Swatch name", with: "loose-blue"
    choose "Hex"
    fill_in "Hex value", with: "#1E5AAA"
    click_on "Create colour"

    assert_text "loose-blue"
    assert_text "#1E5AAA"
    assert_text "No palettes hold this colour yet"
  end

  test "reports a bad new colour without losing what was typed" do
    visit new_color_path

    fill_in "Swatch name", with: "impossible"
    choose "Hex"
    fill_in "Hex value", with: "not-a-colour"
    click_on "Create colour"

    assert_text "is not a colour we can read"
    assert_equal "impossible", find_field("Swatch name").value
  end

  # --- Edit --------------------------------------------------------------

  test "edits a colour name and tags" do
    visit color_path(colors(:deep_indigo))
    click_on "Edit colour"

    fill_in "Swatch name", with: "night-indigo"
    fill_in "Swatch tags", with: "Cool, brand"
    click_on "Save colour"

    assert_text "night-indigo"
    assert_text "cool · brand"
  end

  test "prefills the edit form with what is stored" do
    visit edit_color_path(colors(:signal_red))

    assert_equal "signal-red", find_field("Swatch name").value
    assert_equal "brand, primary", find_field("Swatch tags").value
    assert_equal "227", find_field("R").value
    assert find("#swatch_input_mode_rgb", visible: :all).checked?
  end

  test "opens a cmyk sourced colour in cmyk" do
    visit edit_color_path(colors(:process_cyan))

    assert find("#swatch_input_mode_cmyk", visible: :all).checked?
    assert_equal "100.0", find_field("C").value
  end

  test "edits a colour by its rgb values" do
    visit edit_color_path(colors(:deep_indigo))

    fill_in "R", with: "213"
    fill_in "G", with: "22"
    fill_in "B", with: "43"
    click_on "Save colour"

    # The path, not the hex: the entry row's live preview paints the hex on
    # the form itself, so asserting on it would be satisfied without the save
    # ever having happened.
    assert_current_path color_path(colors(:deep_indigo))
    assert_text "#D5162B"
    assert_equal [ 213, 22, 43 ], colors(:deep_indigo).reload.rgb.values
  end

  test "edits a colour by hex" do
    visit edit_color_path(colors(:deep_indigo))

    choose "Hex"
    fill_in "Hex value", with: "#C77A1A"
    click_on "Save colour"

    assert_current_path color_path(colors(:deep_indigo))
    assert_text "#C77A1A"
    assert_text "Authored in RGB"
  end

  test "switches a colour from rgb to cmyk" do
    visit edit_color_path(colors(:deep_indigo))

    choose "CMYK"
    fill_in "C", with: "0"
    fill_in "M", with: "0"
    fill_in "Y", with: "100"
    fill_in "K", with: "0"
    click_on "Save colour"

    assert_text "Authored in CMYK"
    assert_text "#FFFF00"
  end

  test "reports a validation error without losing what was typed" do
    visit edit_color_path(colors(:deep_indigo))

    fill_in "Swatch name", with: ""
    choose "Hex"
    fill_in "Hex value", with: "not-a-colour"
    click_on "Save colour"

    assert_text "is not a colour we can read"
    assert_equal "not-a-colour", find_field("Hex value").value
    assert_equal 43, colors(:deep_indigo).reload.r
  end

  test "editing a shared colour changes it in every palette holding it" do
    visit edit_color_path(colors(:signal_red))

    fill_in "R", with: "0"
    fill_in "G", with: "0"
    fill_in "B", with: "0"
    click_on "Save colour"

    assert_current_path color_path(colors(:signal_red))

    visit palette_path(palettes(:brand))
    assert_selector "#palette_color_#{palette_colors(:brand_signal_red).id} .swatch[style*='#000000']"

    visit palette_path(palettes(:autumn))
    assert_selector "#palette_color_#{palette_colors(:autumn_signal_red).id} .swatch[style*='#000000']"
  end

  test "warns that a shared colour is shared" do
    visit edit_color_path(colors(:signal_red))

    assert_text "2 palettes"
  end

  test "reaches the edit form from a palette swatch" do
    visit palette_path(palettes(:brand))
    click_on "signal-red"
    click_on "Edit colour"

    assert_equal "signal-red", find_field("Swatch name").value
  end

  # --- Show --------------------------------------------------------------

  test "shows a colour in both spaces with the palettes that hold it" do
    visit color_path(colors(:signal_red))

    assert_text "signal-red"
    assert_text "#E30613"
    assert_text "227"
    assert_text "97.4"
    assert_text "brand"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "marks which space a colour was authored in" do
    visit color_path(colors(:process_cyan))

    assert_text "CMYK"
    assert_text "approximate"
  end

  # A name alone does not tell you what the palette is. Rendering each one as
  # its own strip shows the company the colour keeps.
  test "shows each related palette as a strip of its swatches" do
    visit color_path(colors(:signal_red))

    within "#palette_#{palettes(:brand).id}" do
      assert_text "Brand Core"
      assert_selector ".swatch", count: 3
      assert_selector ".swatch[style*='#111111']"
    end

    within "#palette_#{palettes(:autumn).id}" do
      assert_text "Autumn 2026"
      assert_selector ".swatch", count: 2
      assert_selector ".swatch[style*='#C4842C']"
    end
  end

  test "links from a colour through to a palette that holds it" do
    visit color_path(colors(:signal_red))

    within "#palette_#{palettes(:brand).id}" do
      click_on "Brand Core"
    end

    assert_selector ".swatch-grid"
    assert_text "paper-white"
  end

  test "shows a colour that belongs to no palette" do
    visit color_path(colors(:deep_indigo))

    assert_text "deep-indigo"
    assert_text "No palettes"
  end

  test "looks a colour up by hex and lists every palette containing it" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "looks a colour up by hex without a leading hash" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "e30613"
    click_on "Look up"

    assert_text "Brand Core"
  end

  test "looks a colour up by an rgb triple" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "227, 6, 19"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
  end

  # Every colour stores both spaces, so a search in one finds a colour
  # authored in the other. process-cyan was authored in CMYK; signal-red in
  # RGB. Each is findable from either direction.

  test "finds a cmyk authored colour from its build" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "100, 0, 0, 0"
    click_on "Look up"

    assert_text "process-cyan"
    assert_text "Press Check"
    assert_text "Read as a CMYK build"
  end

  test "finds a cmyk authored colour from its hex" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#00FFFF"
    click_on "Look up"

    assert_text "process-cyan"
    assert_no_text "Read as a CMYK build"
  end

  test "finds an rgb authored colour from a cmyk build" do
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

  test "shows the swatch even when no stored colour matches" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_selector ".swatch[style*='#ABCDEF']"
    assert_text "Not in the library"
  end

  # "We do not have that" on its own sends you away to look somewhere else.
  # The nearest thing on file is usually the answer you were after — and if it
  # is not, the colour you just pasted is one click from joining the library.

  test "offers to add a colour the library does not hold" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_text "Not in the library"
    click_on "Add this colour swatch"

    assert_current_path(/#{Regexp.escape(new_color_path)}/)
    assert_equal "#ABCDEF", find_field("Hex value").value
    assert find("#swatch_input_mode_hex", visible: :all).checked?
  end

  test "adding from a lookup lands the colour in the library" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"
    click_on "Add this colour swatch"

    fill_in "Swatch name", with: "sky"

    before = Color.count
    click_on "Create colour"

    assert_text "No palettes hold this colour yet"
    assert_text "#ABCDEF"
    assert_equal before + 1, Color.count
    assert_equal [ 171, 205, 239 ], Color.find_by(name: "sky").rgb.values
  end

  test "does not offer to add a colour the library already holds" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_no_link "Add this colour swatch"
  end


  test "offers the closest stored colour when the library holds no match" do
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

  test "the closest stored colour links through to it" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#FFFFFF"
    click_on "Look up"

    within(".lookup-nearest") { click_on "paper-white" }

    assert_current_path color_path(colors(:paper_white))
  end

  test "offers a closest colour however far off it is" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#800080"
    click_on "Look up"

    assert_selector ".lookup-nearest .swatch"
  end

  test "does not offer a closest colour when the lookup matched exactly" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_no_selector ".lookup-nearest"
  end

  test "says nothing about a closest colour when the library is empty" do
    PaletteColor.delete_all
    Color.delete_all

    visit lookup_path
    fill_in "Hex, RGB or CMYK", with: "#ABCDEF"
    click_on "Look up"

    assert_text "Not in the library"
    assert_no_selector ".lookup-nearest"
  end

  # The one navigation on this screen is to the colour it found, so the swatch
  # takes that colour's transition name and morphs across rather than fading.
  test "a found colour keeps its transition name through to its page" do
    visit lookup_path

    fill_in "Hex, RGB or CMYK", with: "#E30613"
    click_on "Look up"

    swatch = find(".lookup-result > .swatch")
    assert_match(/view-transition-name:\s*color-#{colors(:signal_red).id}\b/, swatch[:style])
  end

  test "an unmatched lookup names its swatch by the colour itself" do
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

  test "reaches a colour from the palette it sits in" do
    visit palette_path(palettes(:autumn))

    click_on "autumn-ochre"

    assert_text "#C4842C"
    assert_text "Autumn 2026"
  end

  # --- Near duplicates ---------------------------------------------------
  #
  # paper-white is #FAFAF8. A plain #FFFFFF is 17 apart on the redmean scale:
  # near enough that a library holding both is almost certainly holding one
  # colour twice.

  test "asks before adding a colour that is nearly one already in the library" do
    visit new_color_path

    fill_in "Swatch name", with: "off-white"
    choose "Hex"
    fill_in "Hex value", with: "#FFFFFF"

    before = Color.count
    click_on "Create colour"

    assert_text "This is similar to paper-white"
    assert_text "#FAFAF8"
    assert_selector ".warning .swatch", count: 2
    assert_equal before, Color.count, "nothing should have been written while the question stands"
  end

  test "adds it anyway once the question is answered" do
    visit new_color_path

    fill_in "Swatch name", with: "off-white"
    choose "Hex"
    fill_in "Hex value", with: "#FFFFFF"
    click_on "Create colour"

    assert_text "This is similar to paper-white"
    before = Color.count
    click_on "Create anyway"

    assert_no_selector ".warning"
    assert_text "off-white"
    assert_text "#FFFFFF"
    assert_equal before + 1, Color.count
  end

  test "asks again when the colour changes after the warning" do
    visit new_color_path

    fill_in "Swatch name", with: "off-white"
    choose "Hex"
    fill_in "Hex value", with: "#FFFFFF"
    click_on "Create colour"

    assert_text "This is similar to paper-white"
    fill_in "Hex value", with: "#FDFDFD"

    before = Color.count
    click_on "Create anyway"

    # The old warning is still on screen, so asserting on its wording would
    # pass without the second submission ever landing. Only the re-rendered
    # warning names the colour that was just typed.
    within ".warning" do
      assert_text "#FDFDFD"
    end
    assert_equal before, Color.count
  end

  test "refuses an exact duplicate rather than asking about it" do
    visit new_color_path

    fill_in "Swatch name", with: "red again"
    choose "Hex"
    fill_in "Hex value", with: "#E30613"

    before = Color.count
    click_on "Create colour"

    assert_text %(#E30613 is already in the library as "signal-red")
    assert_no_text "This is similar to"
    assert_equal before, Color.count
  end

  test "asks before editing a colour into a near duplicate" do
    visit edit_color_path(colors(:deep_indigo))

    choose "Hex"
    fill_in "Hex value", with: "#FFFFFF"
    click_on "Save colour"

    assert_text "This is similar to paper-white"
    assert_equal [ 43, 74, 138 ], colors(:deep_indigo).reload.rgb.values

    click_on "Save anyway"

    assert_current_path color_path(colors(:deep_indigo))
    assert_equal [ 255, 255, 255 ], colors(:deep_indigo).reload.rgb.values
  end

  test "says nothing about a colour that resembles nothing on file" do
    visit new_color_path

    fill_in "Swatch name", with: "grass"
    choose "Hex"
    fill_in "Hex value", with: "#14A028"

    before = Color.count
    click_on "Create colour"

    # Text only the colour's own page carries: a path built from
    # Color.find_by would be evaluated before the wait, when the row the
    # request is creating may not exist yet.
    assert_text "No palettes hold this colour yet"
    assert_text "#14A028"
    assert_equal before + 1, Color.count
  end

  private
    # Choosing a sort is a whole navigation, so this waits for the re-sorted
    # list before handing back: reading the cards does not retry.
    def sort_by(label, leading:)
      within("[data-filter=sort]") { click_on label }

      assert_selector ".color-list > li:first-child .color-card__name",
        text: leading, exact_text: true
    end

    def filter_unless_live
      click_on "Filter" unless javascript_driver?
    end

    # Reading a collection is two steps — find the nodes, then ask each for its
    # text — and a view transition can swap them in between. synchronize is
    # Capybara's own answer to that: it retries the block on a stale node, and
    # runs it once under rack_test, where nothing moves.
    def card_names
      page.document.synchronize do
        all(".color-card__name", minimum: 1).map(&:text)
      end
    end
end
