require "application_system_test_case"

# Every direct child of the page grid has to be placed on the field. One that
# is not gets auto-placed into a single column, which is how the palette index
# came to be crushed into a sixth of the page: a Turbo Frame is a custom
# element with no default styling, so it arrived as an unplaced inline box and
# the grid gave it one field. The account panel and a line of prose under the
# sign-in form each did the same thing later, which is what moved this from
# reading the stylesheet to measuring the page.
#
# Measuring is the point: it makes no assumption about how the CSS places
# things, so it keeps biting when the placement is rewritten.
class FieldPlacementTest < ApplicationSystemTestCase
  setup { skip "needs a real browser to have widths" unless javascript_driver? }

  # Half the page. A single auto-placed column is a sixth of it; the page head,
  # the one block that legitimately stops short, is two thirds. Half separates
  # those two without pretending to a precision the gutters do not allow.
  NARROWEST = 0.5

  test "no direct child of the page grid is auto placed into a single column" do
    pages.each do |name, path|
      visit path

      narrow = evaluate_script(<<~JS)
        (() => {
          const main = document.querySelector('main.grid');
          const style = getComputedStyle(main);
          const room = main.getBoundingClientRect().width
            - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);

          return Array.from(main.children)
            .map(el => [el.tagName.toLowerCase() + '.' + (el.className || ''),
                        Math.round(el.getBoundingClientRect().width / room * 100)])
            .filter(([, share]) => share > 0 && share < #{(NARROWEST * 100).round});
        })()
      JS

      assert_empty narrow,
        "#{name}: these sit directly on the grid with no field placement, so each " \
        "took a single column instead of the page: #{narrow.inspect}"
    end
  end

  private
    def pages
      {
        "palette index" => palettes_path,
        "palette show" => palette_path(palettes(:brand)),
        "palette form" => new_palette_path,
        "color index" => colors_path,
        "color show" => color_path(colors(:signal_red)),
        "color form" => new_color_path,
        "add a swatch" => new_palette_color_path(palettes(:press)),
        "lookup" => lookup_path(q: "#E30613"),
        "account" => account_path,
        "sign in" => new_session_path,
        "forgotten password" => new_password_path
      }
    end
end
