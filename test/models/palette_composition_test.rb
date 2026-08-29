require "test_helper"

class PaletteCompositionTest < ActiveSupport::TestCase
  # A palette is the set of colors it holds. Two palettes holding the same
  # set are one palette with two names, which is exactly the duplication the
  # library exists to stop.

  test "refuses a palette holding exactly the colors another already holds" do
    palette = Palette.new
    composition = PaletteComposition.new(palette, attributes: { name: "Brand Core Copy" },
      colors: brand_specs)

    assert_not composition.save
    assert_includes palette.errors[:base], %("Brand Core" already holds exactly these colors)
    assert_not palette.persisted?, "the duplicate must not be left behind"
  end

  test "order does not make a palette distinct" do
    palette = Palette.new
    composition = PaletteComposition.new(palette, attributes: { name: "Shuffled" },
      colors: brand_specs.reverse)

    assert_not composition.save
    assert_includes palette.errors[:base], %("Brand Core" already holds exactly these colors)
  end

  test "a different set of colors is fine" do
    palette = Palette.new
    composition = PaletteComposition.new(palette, attributes: { name: "Nearly Brand" },
      colors: brand_specs + [ { id: colors(:deep_indigo).id } ])

    assert composition.save, palette.errors.full_messages.to_sentence
  end

  test "a subset is still its own palette" do
    palette = Palette.new
    composition = PaletteComposition.new(palette, attributes: { name: "Half Brand" },
      colors: brand_specs.first(2))

    assert composition.save, palette.errors.full_messages.to_sentence
  end

  test "empty palettes do not duplicate one another" do
    palette = Palette.new
    composition = PaletteComposition.new(palette, attributes: { name: "Also Unfilled" }, colors: [])

    assert composition.save, palette.errors.full_messages.to_sentence
  end

  test "refuses an append that completes a duplicate" do
    palette = palettes(:press)
    PaletteComposition.new(palette, attributes: {}, colors: brand_specs.first(2)).save

    composition = PaletteComposition.new(palette, attributes: {}, append: [ brand_specs.last ])

    assert_not composition.save
    assert_includes palette.errors[:base], %("Brand Core" already holds exactly these colors)
    assert_equal 2, palette.palette_colors.reload.size, "the palette must be left as it was"
  end

  test "a palette is not a duplicate of itself" do
    palette = palettes(:brand)

    assert PaletteComposition.new(palette, attributes: { name: "Brand Core Renamed" },
      colors: brand_specs).save, palette.errors.full_messages.to_sentence
  end

  test "replacing renumbers positions from zero" do
    palette = palettes(:brand)
    PaletteComposition.new(palette, attributes: {}, colors: brand_specs.last(2)).save

    assert_equal [ 0, 1 ], palette.palette_colors.reload.pluck(:position)
  end

  private
    def brand_specs
      palettes(:brand).palette_colors.order(:position).map { |membership| { id: membership.color_id } }
    end
end
