require "application_system_test_case"

# What only a real browser can answer.
#
# The rest of the suite asserts text and selectors, which are true at any
# width — a list crushed into one column of six passes every one of them. That
# is exactly how the palette index shipped collapsed. These measure instead,
# and they only run under SYSTEM_TEST_DRIVER=selenium.
class BrowserTest < ApplicationSystemTestCase
  setup do
    skip "needs a real browser; run with SYSTEM_TEST_DRIVER=selenium" unless javascript_driver?
  end

  # --- Layout ------------------------------------------------------------

  test "the palette results fill the field the filters fill" do
    visit palettes_path

    assert_in_delta width_of(".filters"), width_of(".palette-list"), 1,
      "the results are not spanning the field — something between them and the grid is unplaced"
  end

  test "the colour results fill the field the filters fill" do
    visit colors_path

    assert_in_delta width_of(".filters"), width_of(".color-list"), 1
  end

  test "palette cards sit three to a row on a wide window" do
    visit palettes_path

    tops = tops_of(".palette-strip")
    assert_equal 3, tops.count(tops.first), "expected three cards on the first row, got #{tops.inspect}"
  end

  test "a palette's swatches fill the width whatever their number" do
    visit palette_path(palettes(:brand))

    row = width_of(".swatch-grid")
    cards = evaluate_script(
      "Array.from(document.querySelectorAll('.swatch-grid > li'))" \
      ".map(el => el.getBoundingClientRect().width).reduce((a, b) => a + b, 0)"
    )
    gutters = (all(".swatch-grid > li").size - 1) * 24

    assert_in_delta row, cards + gutters, 2,
      "three swatches left #{(row - cards - gutters).round}px of the row unused"
  end

  test "the page head stops short of the right edge" do
    visit palettes_path

    assert width_of(".page-head") < width_of(".filters"),
      "the head should span four fields against the filter bar's six"
  end

  test "no page scrolls sideways" do
    pages.each do |name, path|
      visit path

      overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert overflow <= 1, "#{name} overflows its width by #{overflow}px"
    end
  end

  test "the page actions sit on one line" do
    visit palette_path(palettes(:brand))

    tops = tops_of(".page-actions > *")
    assert_equal 3, tops.size, "expected all three actions inside the row"
    assert_equal 1, tops.uniq.size, "the actions wrapped onto #{tops.uniq.size} lines: #{tops.inspect}"
  end

  test "channel values never break mid-value" do
    visit palette_path(palettes(:brand))

    # Each channel is one unbreakable unit, so a narrow card wraps between
    # them rather than splitting "K 11.0" across two lines.
    assert_selector ".swatch-detail .channel", minimum: 7
    tops_of(".swatch-detail:first-child .channels dd .channel").each_slice(1) { |t| assert t.first.is_a?(Integer) }
  end

  # --- Behaviour the no-JS suite cannot reach ----------------------------

  test "a row of a form does not stretch across the page" do
    visit lookup_path

    # An unbounded row put the field across the whole width and stranded the
    # button against the right edge.
    assert width_of(".form--inline") <= width_of(".page-head"),
      "the inline form is wider than the text column it sits under"
  end

  test "the preview appears only once there is something to preview" do
    visit new_palette_color_path(palettes(:press), source: "new")

    assert_hidden ".preview"

    fill_in "R", with: "227"
    fill_in "G", with: "6"
    fill_in "B", with: "19"

    assert_visible ".preview"
  end

  test "the swatch preview paints as values are typed" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "R", with: "227"
    fill_in "G", with: "6"
    fill_in "B", with: "19"

    assert_equal "rgb(227, 6, 19)", preview_background
    assert_text "#E30613"
  end

  test "the preview follows a change of space" do
    visit new_palette_color_path(palettes(:press), source: "new")

    choose "CMYK"
    fill_in "C", with: "0"
    fill_in "M", with: "0"
    fill_in "Y", with: "100"
    fill_in "K", with: "0"

    assert_equal "rgb(255, 255, 0)", preview_background
  end

  test "choosing a space shows only that space's fields" do
    visit new_palette_color_path(palettes(:press), source: "new")

    assert_visible "[data-mode='rgb']"
    assert_hidden "[data-mode='cmyk']"
    assert_hidden "[data-mode='hex']"

    choose "Hex"

    assert_hidden "[data-mode='rgb']"
    assert_visible "[data-mode='hex']"
  end

  test "the source switch shows one panel at a time" do
    visit new_palette_color_path(palettes(:press))

    assert_visible "[data-source='library']"
    assert_hidden "[data-source='new']"

    choose "New colour"

    assert_hidden "[data-source='library']"
    assert_visible "[data-source='new']"
  end

  # A row of controls added under the search is one declaration away from
  # pushing the search field or its button out of place.

  test "the search field and its button share a line" do
    [ colors_path, palettes_path ].each do |path|
      visit path

      field = rect_of(".filter-form > .field")
      button = rect_of(".filter-form input[type=submit]")
      row = rect_of(".filters")

      # The field against the whole row, not against its own form: the form
      # collapses along with the field, so comparing the two would agree they
      # are fine.
      assert_operator field["width"], :>, row["width"] / 3, "#{path}: the search field collapsed"
      assert_operator button["left"], :>=, field["left"] + field["width"] - 1,
        "#{path}: the Filter button wrapped under the search field"
    end
  end

  test "the sort options sit on one line of their own, below the search" do
    visit colors_path

    field = rect_of(".filter-form > .field")
    sort = rect_of(".sort-filter")

    assert_equal 1, tops_of(".sort-filter li").uniq.size,
      "the sort options wrapped onto more than one line"
    assert_operator sort["top"], :>=, field["top"] + field["height"] - 1,
      "the sort options crowded onto the search line"
    assert_equal 0, evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"),
      "the sort row pushed the page sideways"
  end

  # The tag links live outside the results frame, so an order that only swapped
  # that frame would leave them carrying the old one.
  test "choosing an order keeps it through a tag filter" do
    visit colors_path

    within(".sort-filter") { click_on "Dark first" }
    assert_selector ".color-list > li:first-child", text: "ink-black"

    click_on "brand"

    assert_selector ".color-list > li", count: 3
    assert_equal [ "ink-black", "signal-red", "paper-white" ],
      all(".color-card__name").map(&:text)
  end

  test "search filters as you type, without pressing Filter" do
    visit palettes_path

    fill_in "Search", with: "autumn"

    assert_text "1 of 4 palettes"
    assert_no_text "Brand Core"
  end

  test "tags are edited in place rather than on their own page" do
    visit palette_path(palettes(:press))

    click_on "Edit tags"
    fill_in "Tags", with: "print, archive"
    click_on "Save tags"

    assert_text "archive"
    assert_current_path palette_path(palettes(:press))
  end

  private
    def pages
      {
        "palette index" => palettes_path,
        "palette show" => palette_path(palettes(:brand)),
        "palette form" => new_palette_path,
        "colour index" => colors_path,
        "colour show" => color_path(colors(:signal_red)),
        "colour form" => new_color_path,
        "add a swatch" => new_palette_color_path(palettes(:press)),
        "lookup" => lookup_path(q: "#E30613")
      }
    end

    def rect_of(selector)
      evaluate_script(
        "(({top, left, width, height}) => ({top, left, width, height}))" \
        "(document.querySelector(#{selector.to_json}).getBoundingClientRect())"
      )
    end

    def width_of(selector)
      evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
    end

    def tops_of(selector)
      evaluate_script(
        "Array.from(document.querySelectorAll(#{selector.to_json}))" \
        ".map(el => Math.round(el.getBoundingClientRect().top))"
      )
    end

    def preview_background
      evaluate_script(
        "getComputedStyle(document.querySelector('[data-swatch-preview-target=\"preview\"]')).backgroundColor"
      )
    end

    def assert_visible(selector)
      assert find(selector, visible: :all).visible?, "#{selector} should be showing"
    end

    def assert_hidden(selector)
      assert_not find(selector, visible: :all).visible?, "#{selector} should be hidden"
    end
end
