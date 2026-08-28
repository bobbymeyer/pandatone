require "application_system_test_case"

class ColorsTest < ApplicationSystemTestCase
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
