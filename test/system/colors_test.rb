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

    click_on "print"

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

    click_on "brand"
    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_text "ink-black"
    assert_no_text "paper-white"
  end

  test "a colour card is one link, not two to the same place" do
    visit colors_path

    within "#color_#{colors(:signal_red).id}" do
      assert_selector "a", count: 1
      assert_equal "/colors/#{colors(:signal_red).id}", find("a")[:href]
    end
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

  test "creates a colour that belongs to no palette yet" do
    visit colors_path
    click_on "New colour"

    fill_in "Swatch name", with: "loose-blue"
    choose "Hex"
    fill_in "Hex value", with: "#2B4A8A"
    click_on "Create colour"

    assert_text "loose-blue"
    assert_text "#2B4A8A"
    assert_text "No palettes hold this colour yet"
  end

  test "reports a bad new colour without losing what was typed" do
    visit new_color_path

    fill_in "Swatch name", with: "impossible"
    fill_in "R", with: "999"
    click_on "Create colour"

    assert_text "must be less than or equal to 255"
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

    fill_in "R", with: "227"
    fill_in "G", with: "6"
    fill_in "B", with: "19"
    click_on "Save colour"

    assert_text "#E30613"
  end

  test "edits a colour by hex" do
    visit edit_color_path(colors(:deep_indigo))

    choose "Hex"
    fill_in "Hex value", with: "#C4842C"
    click_on "Save colour"

    assert_text "#C4842C"
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
    fill_in "R", with: "999"
    click_on "Save colour"

    assert_text "must be less than or equal to 255"
    assert_equal "999", find_field("R").value
    assert_equal 43, colors(:deep_indigo).reload.r
  end

  test "editing a shared colour changes it in every palette holding it" do
    visit edit_color_path(colors(:signal_red))

    fill_in "R", with: "0"
    fill_in "G", with: "0"
    fill_in "B", with: "0"
    click_on "Save colour"

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

    fill_in "Hex or RGB", with: "#E30613"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "looks a colour up by hex without a leading hash" do
    visit lookup_path

    fill_in "Hex or RGB", with: "e30613"
    click_on "Look up"

    assert_text "Brand Core"
  end

  test "looks a colour up by an rgb triple" do
    visit lookup_path

    fill_in "Hex or RGB", with: "227, 6, 19"
    click_on "Look up"

    assert_text "signal-red"
    assert_text "Brand Core"
  end

  test "shows the swatch even when no stored colour matches" do
    visit lookup_path

    fill_in "Hex or RGB", with: "#ABCDEF"
    click_on "Look up"

    assert_selector ".swatch[style*='#ABCDEF']"
    assert_text "Not in the library"
  end

  test "reports an unreadable lookup" do
    visit lookup_path

    fill_in "Hex or RGB", with: "wat"
    click_on "Look up"

    assert_text "Could not read"
  end

  test "reaches a colour from the palette it sits in" do
    visit palette_path(palettes(:autumn))

    click_on "autumn-ochre"

    assert_text "#C4842C"
    assert_text "Autumn 2026"
  end
end
