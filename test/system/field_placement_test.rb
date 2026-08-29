require "application_system_test_case"

# Every direct child of the page grid has to be placed on the field. One that
# is not gets auto-placed into a single column, which is how the palette index
# came to be crushed into a sixth of the page: a Turbo Frame is a custom
# element with no default styling, so it arrived as an unplaced inline box and
# the grid gave it one field.
#
# This checks the whole class of mistake rather than that one instance: it
# reads which selectors grid.css actually places, then walks the real pages.
class FieldPlacementTest < ApplicationSystemTestCase
  test "every direct child of the page grid is placed on the field" do
    placed = placed_selectors
    assert_not_empty placed

    pages.each do |name, path|
      visit path

      all("main > *", visible: :all).each do |element|
        classes = element[:class].to_s.split
        identifiers = classes + [ element.tag_name ]

        assert_any_placed identifiers, placed,
          "#{name}: <#{element.tag_name} class=#{element[:class].inspect}> sits directly on the " \
          "grid with no field placement, so it will take a single column"
      end
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
        "lookup" => lookup_path(q: "#E30613")
      }
    end

    # Selectors grid.css gives an explicit grid-column, reduced to the class or
    # tag names they hinge on.
    def placed_selectors
      css = Rails.root.join("app/assets/stylesheets/grid.css").read

      css.scan(/([^{}]+)\{[^}]*grid-column:[^}]*\}/m).flatten.flat_map do |selectors|
        selectors.split(",").map { |selector| selector.strip[/[.\w-]+\z/].to_s.delete_prefix(".") }
      end.reject(&:empty?).uniq
    end

    def assert_any_placed(identifiers, placed, message)
      assert identifiers.any? { |identifier| placed.include?(identifier) }, message
    end
end
