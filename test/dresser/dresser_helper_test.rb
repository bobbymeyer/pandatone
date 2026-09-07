require "test_helper"

module Pandatone
  class DresserHelperTest < ActionView::TestCase
    include Pandatone::DresserHelper

    # The picker shows a palette in grey, at its own lightnesses: the preview
    # is where colour belongs, and what a palette is for here is how its
    # values are spread.
    test "a palette strip is its colours in rank, as greys of their own lightness" do
      html = Nokogiri::HTML5.fragment(palette_strip(dresser_palette("#12120F", "#FAF8F4", "#C1272D")))
      greys = html.css(".palette-swatch").map { |swatch| swatch["style"][/#\h{6}/] }

      assert_equal 3, greys.size
      assert_equal greys.sort.reverse, greys, "lightest first"
      assert_not_includes greys, "#C1272D", "the palette's own colours are not here"
      assert_equal %w[ sample-1 sample-2 sample-0 ], html.css(".palette-swatch__name").map(&:text)
    end

    test "a slot swatch is the colour, or a hatch when a rule has replaced the rank" do
      assert_includes slot_swatch("#E30613"), "background: #E30613"
      assert_includes slot_swatch("#E30613", ruled: true), "slot-swatch--ruled"
      assert_not_includes slot_swatch("#E30613", ruled: true), "#E30613"
    end

    test "a rule in words says the two kinds it knows and asks about the rest" do
      wearer = Wearer.create!(name: "Awning", slot_count: 2)
      colorway = wearer.colorways.create!(palette: dresser_palette("#FAF8F4", "#12120F"))

      assert_equal "By rank", rule_in_words(colorway.rule_for(0))
      assert_equal "Palette colour 1", rule_in_words(Wearer::Rule.new(colorway: colorway, rank: 0, kind: "assigned_slot", settings: { "slot" => 1 }))
      assert_equal "Stepping", rule_in_words(Wearer::Rule.new(colorway: colorway, rank: 0, kind: "increment")) { |_rule| "Stepping" }
    end
  end
end
