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

  # The color index and the color page share a transition name per color,
  # so a swatch morphs across that navigation too.
  test "a color swatch keeps its transition name from the index to its page" do
    color = colors(:signal_red)

    visit colors_path
    card_swatch = find("#color_#{color.id} .swatch")
    assert_match(/view-transition-name:\s*color-#{color.id}\b/, card_swatch[:style])

    visit color_path(color)
    detail_swatch = find(".color-detail > .swatch")
    assert_match(/view-transition-name:\s*color-#{color.id}\b/, detail_swatch[:style])
  end

  test "transition names are unique on the color index" do
    visit colors_path

    names = all(".swatch").map { |swatch| swatch[:style][/view-transition-name:\s*([\w-]+)/, 1] }

    assert_equal 6, names.compact.size
    assert_equal names.uniq, names
  end

  test "leads the nav with colors" do
    visit root_path

    assert_equal [ "Colors", "Palettes", "Lookup" ], all(".masthead__nav a").map(&:text)
  end

  # The typeface ships with the app. This is a local tool, so it should not
  # need a third party to be reachable in order to render correctly.
  test "self hosts the typeface" do
    visit root_path

    assert_selector "link[rel='preload'][as='font'][href*='archivo']", visible: false
    assert_no_selector "link[href*='fonts.googleapis.com']", visible: false
    assert_no_selector "link[href*='fonts.gstatic.com']", visible: false
  end

  # The color page now carries its own swatch plus a strip per palette that
  # holds it, and the color appears inside each of those strips.
  test "transition names are unique on a color page" do
    visit color_path(colors(:signal_red))

    names = all(".swatch").map { |swatch| swatch[:style][/view-transition-name:\s*([\w-]+)/, 1] }

    assert_equal 6, names.compact.size
    assert_equal names.uniq, names
  end

  # A transition snapshot of :root is sized to the viewport *including* the
  # scrollbar, while the page is laid out inside it — so for the length of
  # every navigation the document was 15px wider than its own viewport and
  # really did scroll sideways. It settled back to zero afterwards, which is
  # why every static measurement of these pages came back clean.
  test "a navigation never gives the page somewhere to scroll sideways" do
    skip "needs a real browser" unless javascript_driver?

    page.driver.browser.manage.window.resize_to(390, 844)
    visit palettes_path
    watch_horizontal_scroll

    click_on "Colors"
    assert_text "signal-red"

    assert_equal 0, widest_scroll_seen,
      "the page could be scrolled sideways while the transition ran"
  ensure
    page.driver.browser.manage.window.resize_to(*ApplicationSystemTestCase::SCREEN_SIZE) if javascript_driver?
  end

  test "moves between every screen" do
    visit root_path
    assert_text "Palettes"

    click_on "Brand Core"
    assert_text "Brand Core"

    click_on "signal-red"
    assert_text "#E30613"

    click_on "Colors"
    assert_text "signal-red"

    click_on "Lookup"
    assert_text "Hex, RGB or CMYK"

    click_on "Palettes"
    assert_text "Brand Core"
  end

  private
    # Samples every frame for the length of a navigation, because the overflow
    # this catches exists only while the transition runs: asking afterwards
    # always says zero.
    def watch_horizontal_scroll
      execute_script(<<~JS)
        window.__widest = 0;
        (function sample() {
          const page = document.documentElement;
          const room = page.scrollWidth - page.clientWidth;
          if (room > window.__widest) window.__widest = room;
          if ((window.__frames = (window.__frames || 0) + 1) < 240) requestAnimationFrame(sample);
        })();
      JS
    end

    def widest_scroll_seen
      evaluate_script("window.__widest")
    end
end
