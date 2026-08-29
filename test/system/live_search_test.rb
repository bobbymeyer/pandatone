require "application_system_test_case"

# The live filtering itself needs a browser, so these pin the wiring instead:
# that each search form is hooked up to the controller and aimed at a frame
# that actually exists on the page. A mismatched frame name fails silently in
# the browser — the form just does nothing — which is exactly the kind of
# break worth a test.
class LiveSearchTest < ApplicationSystemTestCase
  test "the palette search is wired to a frame on the page" do
    visit palettes_path

    assert_live_search_wired ".filter-form"
    assert_selector "turbo-frame#palettes .palette-list"
  end

  test "the colour search is wired to a frame on the page" do
    visit colors_path

    assert_live_search_wired ".filter-form"
    assert_selector "turbo-frame#colors .color-list"
  end

  test "the library search is wired to a frame on the page" do
    visit new_palette_color_path(palettes(:press), source: "library")

    assert_live_search_wired ".library-picker .filter-form"
    assert_selector "turbo-frame#library .color-list"
  end

  test "each search still submits without javascript" do
    visit palettes_path

    fill_in "Search", with: "autumn"
    click_on "Filter"

    assert_text "Autumn 2026"
    assert_no_text "Brand Core"
  end

  test "the library search still submits without javascript" do
    visit new_palette_color_path(palettes(:press), source: "library")

    fill_in "Search", with: "ink"
    click_on "Filter"

    assert_selector "#color_#{colors(:ink_black).id}"
    assert_no_selector "#color_#{colors(:signal_red).id}"
  end

  private
    def assert_live_search_wired(selector)
      form = find(selector, visible: :all)

      assert_equal "live-search", form["data-controller"]
      assert_includes form["data-action"].to_s, "live-search#search"

      frame = form["data-turbo-frame"]
      assert frame.present?, "#{selector} does not target a frame"
      assert_selector "turbo-frame##{frame}", visible: :all,
        count: 1, wait: 0
    end
end
