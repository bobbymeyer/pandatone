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
