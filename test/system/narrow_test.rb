require "application_system_test_case"

# The app was designed, screenshotted and measured at one width for its whole
# life. These run it at the two the grid has breakpoints for.
class NarrowTest < ApplicationSystemTestCase
  SMALL_PHONE = [ 320, 568 ].freeze
  PHONE = [ 390, 844 ].freeze
  TABLET = [ 768, 1024 ].freeze

  setup { skip "needs a real browser" unless javascript_driver? }

  # Capybara reuses one window for the whole process, so a test that resizes it
  # and walks away runs every test after it at that width.
  teardown { resize(*ApplicationSystemTestCase::SCREEN_SIZE) if javascript_driver? }

  # No tolerance. A page that scrolls sideways by one pixel scrolls sideways.
  test "no page scrolls sideways at any width" do
    [ SMALL_PHONE, PHONE, TABLET ].each do |size|
      pages.each do |name, path|
        visit path
        resize_viewport(*size)

        assert_equal 0, overflow, "#{name} at #{size.first}px overflows by #{overflow}px"
      end
    end
  end

  # Fixture names all carry a hyphen, which is a break opportunity, so for most
  # of this app's life every measurement was taken on text that could wrap.
  # A name is free text: "Supercalifragilistic" has nowhere to break, and a box
  # that cannot break it is a box that grows until the page scrolls.
  test "a name with nowhere to break does not push the page sideways" do
    color = Color.create!(name: "Xanthocarpouserythrocephalousmegalodontosaurus",
      source_space: Color::RGB, r: 9, g: 8, b: 7,
      tags: [ "Pantoneesquereferencelibrarytagthatneverbreaks" ])
    palette = Palette.create!(name: "Supercalifragilisticexpialidociousandthensome",
      tags: [ "Pantoneesquereferencelibrarytagthatneverbreaks" ])
    palette.palette_colors.create!(color: color, position: 0)

    { "the color" => color_path(color), "the palette" => palette_path(palette),
      "the color index" => colors_path, "the palette index" => palettes_path,
      "adding a swatch" => new_palette_color_path(palettes(:press)) }.each do |name, path|
      visit path
      resize_viewport(*SMALL_PHONE)

      assert_equal 0, overflow, "#{name} overflows by #{overflow}px"
    end
  end

  # 39 of these were 14px tall on a phone, which is what a row of 12px links
  # measures when nobody looks at it on one.
  test "every tap target clears the 24px minimum" do
    pages.each do |name, path|
      visit path
      resize_viewport(*PHONE)
      # A link inside a sentence is exempt: it is placed by the prose around
      # it, and padding one out would break the line it sits in.
      small = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('main a, main button, main input[type=submit]'))
          .filter(el => !el.closest('.page-lede, .empty, .hint, .provenance'))
          .map(el => [el.className || el.tagName, Math.round(el.getBoundingClientRect().height)])
          .filter(([, h]) => h > 0 && h < 24)
      JS

      assert_empty small, "#{name} has targets under 24px: #{small.uniq.inspect}"
    end
  end

  # The block changes as a system: all three registers stack, rather than two
  # wrapping while the search keeps its inline label.
  test "the filter registers stack together when they cannot sit inline" do
    [ PHONE, TABLET ].each do |size|
      visit colors_path
      resize_viewport(*size)

      lefts = evaluate_script(<<~JS)
        [document.querySelector('.filters .filter-form > .field'),
         ...document.querySelectorAll('.filter-row')]
          .map(row => Array.from(row.children).map(el => Math.round(el.getBoundingClientRect().left)))
      JS

      stacked = lefts.map { |row| row.uniq.size == 1 }
      assert_equal [ stacked.first ] * 3, stacked,
        "at #{size.first}px the registers disagree about stacking: #{lefts.inspect}"
    end
  end

  private
    def overflow
      evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end

    def resize(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end

    # Selenium sizes the window; the viewport is narrower by whatever the
    # scrollbar takes, which is 15px in this browser and nothing at all on the
    # phones these numbers are named after. Measuring that once per page and
    # asking for a window that much wider is what makes 320 mean 320.
    def resize_viewport(width, height)
      resize(width, height)
      slack = width - evaluate_script("document.documentElement.clientWidth")

      resize(width + slack, height) if slack.positive?
    end

    def pages
      {
        "palette index" => palettes_path,
        "palette" => palette_path(palettes(:brand)),
        "color index" => colors_path,
        "color" => color_path(colors(:signal_red)),
        "add a swatch" => new_palette_color_path(palettes(:press)),
        "fork" => new_palette_path(from: palettes(:brand).id),
        "new color" => new_color_path,
        "lookup" => lookup_path(q: "#ABCDEF"),
        "account" => account_path,
        "sign in" => new_session_path
      }
    end
end
