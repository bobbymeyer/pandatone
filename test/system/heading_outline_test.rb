require "application_system_test_case"

# One rule, everywhere: the page title is h1, a section heading is h2, and an
# item's name sits one level under whatever heading it belongs to. Skipping a
# level leaves a screen reader announcing a structure the page does not have,
# and three pages had drifted apart before this existed.
class HeadingOutlineTest < ApplicationSystemTestCase
  test "no page skips a heading level" do
    each_page do |name, path|
      visit path
      levels = all("h1, h2, h3, h4", visible: :all).map { |heading| heading.tag_name[1].to_i }

      assert_equal 1, levels.count(1), "#{name} should have exactly one h1"
      levels.each_cons(2) do |before, after|
        assert_operator after, :<=, before + 1,
          "#{name} jumps from h#{before} to h#{after}: #{levels.inspect}"
      end
    end
  end

  test "the same kind of thing is not headed differently from page to page" do
    visit palettes_path
    index = first(".palette-strip__name").tag_name

    visit color_path(colors(:signal_red))
    nested = within("section.memberships") { first(".palette-strip__name").tag_name }

    assert_equal "h2", index, "a strip is the page's own content on the index"
    assert_equal "h3", nested, "the same strip sits under the Palettes heading on a colour"
  end

  private
    def each_page
      {
        "palette index" => palettes_path,
        "palette show" => palette_path(palettes(:brand)),
        "new palette" => new_palette_path,
        "fork palette" => new_palette_path(from: palettes(:brand).id),
        "edit palette" => edit_palette_path(palettes(:brand)),
        "colour index" => colors_path,
        "colour show" => color_path(colors(:signal_red)),
        "new colour" => new_color_path,
        "edit colour" => edit_color_path(colors(:signal_red)),
        "add a swatch" => new_palette_color_path(palettes(:press)),
        "add a swatch, new" => new_palette_color_path(palettes(:press), source: "new"),
        "lookup" => lookup_path,
        "lookup hit" => lookup_path(q: "#E30613"),
        "lookup miss" => lookup_path(q: "#ABCDEF")
      }.each { |name, path| yield name, path }
    end
end
