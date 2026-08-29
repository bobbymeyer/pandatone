require "application_system_test_case"

class PaletteIndexTest < ApplicationSystemTestCase
  # The shelf of palettes: what each strip shows, how the shelf is narrowed,
  # and the order it comes back in.

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

  test "lists palettes by name until asked otherwise" do
    visit palettes_path

    assert_equal Palette.order(:name).pluck(:name), strip_names
    assert_selector "[data-filter=sort] .tag.active", text: "Name", exact_text: true
  end

  test "sorts palettes by color, dark first and light first" do
    visit palettes_path

    sort_by "Dark first", leading: "Autumn 2026"
    sort_by "Light first", leading: "Press Check"
    sort_by "Color", leading: "Brand Core"
  end

  test "an empty palette sorts last however the colors run" do
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

  test "navigates from a swatch on the index through to the color" do
    visit palettes_path

    within "#palette_#{palettes(:brand).id}" do
      click_on "Brand Core"
    end

    click_on "signal-red"

    assert_text "signal-red"
    assert_text "#E30613"
  end

  private
    def sort_by(label, leading:)
      super(label, leading: leading, list: ".palette-list", name: ".palette-strip__name")
    end
end
