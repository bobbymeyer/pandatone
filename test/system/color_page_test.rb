require "application_system_test_case"

class ColorPageTest < ApplicationSystemTestCase
  # One color's own page: both spaces, the palettes holding it, its tags,
  # and the hex you came for.

  test "shows a color in both spaces with the palettes that hold it" do
    visit color_path(colors(:signal_red))

    assert_text "signal-red"
    assert_text "#E30613"
    assert_text "227"
    assert_text "97.4"
    assert_text "brand"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "marks which space a color was authored in" do
    visit color_path(colors(:process_cyan))

    assert_text "CMYK"
    assert_text "approximate"
  end

  test "shows a color that belongs to no palette" do
    visit color_path(colors(:deep_indigo))

    assert_text "deep-indigo"
    assert_text "No palettes"
  end

  # A name alone does not tell you what the palette is. Rendering each one as
  # its own strip shows the company the color keeps.
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

  test "links from a color through to a palette that holds it" do
    visit color_path(colors(:signal_red))

    within "#palette_#{palettes(:brand).id}" do
      click_on "Brand Core"
    end

    assert_selector ".swatch-grid"
    assert_text "paper-white"
  end

  test "reaches a color from the palette it sits in" do
    visit palette_path(palettes(:autumn))

    click_on "autumn-ochre"

    assert_text "#C4842C"
    assert_text "Autumn 2026"
  end

  test "edits a color's tags in place" do
    visit color_path(colors(:deep_indigo))

    click_on "Edit tags"
    fill_in "Tags", with: "Cool, brand"
    click_on "Save tags"

    assert_current_path color_path(colors(:deep_indigo))
    assert_text "cool · brand"
  end

  test "says so rather than showing nothing when a color has no tags" do
    colors(:deep_indigo).update!(tags: [])

    visit color_path(colors(:deep_indigo))

    assert_text "Untagged"
  end

  # A hex is on screen to be taken somewhere else, so it is a button. The
  # value stays readable inside it, which is what keeps the page usable when
  # the clipboard is not.
  test "every hex on screen is a copy button carrying its own value" do
    visit color_path(colors(:signal_red))

    button = find(".copy", match: :first)
    assert_equal "#E30613", button.text
    assert_equal "#E30613", button["data-clipboard-text-value"]
    assert_equal "Copy #E30613", button["aria-label"]
  end

  test "hexes are copy buttons on the index and the lookup too" do
    visit colors_path
    assert_selector ".color-card .copy", minimum: 6

    visit lookup_path(q: "#E30613")
    assert_selector ".copy", text: "#E30613"
  end
end
