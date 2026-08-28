require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "opts the whole app into cross-document view transitions" do
    visit palettes_path

    assert_selector "meta[name='view-transition'][content='same-origin']", visible: false
  end

  # The signature interaction: the first swatch of the Brand Core strip on the
  # index is the same element as the first swatch on the palette page, so the
  # browser morphs it across the navigation instead of crossfading the page.
  test "gives each swatch a stable transition name so it can morph between pages" do
    membership = palette_colors(:brand_signal_red)

    visit palettes_path
    strip_swatch = find("#palette_#{palettes(:brand).id} .swatch", match: :first)
    assert_match(/view-transition-name:\s*palette-color-#{membership.id}\b/, strip_swatch[:style])

    visit palette_path(palettes(:brand))
    detail_swatch = find("#palette_color_#{membership.id} .swatch")
    assert_match(/view-transition-name:\s*palette-color-#{membership.id}\b/, detail_swatch[:style])
  end

  # A duplicated transition name silently disables the morph, and signal-red
  # sits in two of the palettes on the index, so this is a live hazard rather
  # than a theoretical one.
  test "transition names are unique within a page" do
    visit palettes_path

    names = all(".swatch").map { |swatch| swatch[:style][/view-transition-name:\s*([\w-]+)/, 1] }

    assert_equal 6, names.compact.size
    assert_equal names.uniq, names
  end

  # The colour index and the colour page share a transition name per colour,
  # so a swatch morphs across that navigation too.
  test "a colour swatch keeps its transition name from the index to its page" do
    color = colors(:signal_red)

    visit colors_path
    card_swatch = find("#color_#{color.id} .swatch")
    assert_match(/view-transition-name:\s*color-#{color.id}\b/, card_swatch[:style])

    visit color_path(color)
    detail_swatch = find(".color-detail > .swatch")
    assert_match(/view-transition-name:\s*color-#{color.id}\b/, detail_swatch[:style])
  end

  test "transition names are unique on the colour index" do
    visit colors_path

    names = all(".swatch").map { |swatch| swatch[:style][/view-transition-name:\s*([\w-]+)/, 1] }

    assert_equal 6, names.compact.size
    assert_equal names.uniq, names
  end

  test "moves between every screen" do
    visit root_path
    assert_text "Palettes"

    click_on "Brand Core"
    assert_text "Brand Core"

    click_on "signal-red"
    assert_text "#E30613"

    click_on "Colours"
    assert_text "signal-red"

    click_on "Lookup"
    assert_text "Hex or RGB"

    click_on "Palettes"
    assert_text "Brand Core"
  end
end
