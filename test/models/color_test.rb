require "test_helper"

class ColorTest < ActiveSupport::TestCase
  # --- Validations -------------------------------------------------------

  test "is valid with rgb source values" do
    assert_predicate Color.new(name: "test", source_space: "rgb", r: 10, g: 20, b: 30), :valid?
  end

  test "requires a name" do
    color = Color.new(source_space: "rgb", r: 0, g: 0, b: 0)
    assert_not color.valid?
    assert_includes color.errors[:name], "can't be blank"
  end

  test "requires a source space" do
    color = Color.new(name: "test", r: 0, g: 0, b: 0)
    assert_not color.valid?
    assert_includes color.errors[:source_space], "is not included in the list"
  end

  test "rejects an unknown source space" do
    color = Color.new(name: "test", source_space: "lab", r: 0, g: 0, b: 0)
    assert_not color.valid?
    assert_includes color.errors[:source_space], "is not included in the list"
  end

  test "accepts both known source spaces" do
    assert_predicate Color.new(name: "a", source_space: "rgb", r: 1, g: 1, b: 1), :valid?
    assert_predicate Color.new(name: "b", source_space: "cmyk", c: 1, m: 1, y: 1, k: 1), :valid?
  end

  test "rejects rgb channels outside 0..255" do
    [ [ 256, 0, 0 ], [ -1, 0, 0 ], [ 0, 300, 0 ], [ 0, 0, -20 ] ].each do |r, g, b|
      color = Color.new(name: "test", source_space: "rgb", r: r, g: g, b: b)
      assert_not color.valid?, "expected rgb(#{r}, #{g}, #{b}) to be rejected"
    end
  end

  test "accepts rgb channels at the bounds" do
    assert_predicate Color.new(name: "lo", source_space: "rgb", r: 0, g: 0, b: 0), :valid?
    assert_predicate Color.new(name: "hi", source_space: "rgb", r: 255, g: 255, b: 255), :valid?
  end

  test "rejects non integer rgb channels" do
    color = Color.new(name: "test", source_space: "rgb", r: 12.5, g: 0, b: 0)
    assert_not color.valid?
    assert_includes color.errors[:r], "must be an integer"
  end

  test "requires rgb channels when the source space is rgb" do
    color = Color.new(name: "test", source_space: "rgb")
    assert_not color.valid?
    assert_includes color.errors[:r], "can't be blank"
    assert_includes color.errors[:g], "can't be blank"
    assert_includes color.errors[:b], "can't be blank"
  end

  test "rejects cmyk channels outside 0..100" do
    [ [ 101, 0, 0, 0 ], [ 0, -0.1, 0, 0 ], [ 0, 0, 100.1, 0 ], [ 0, 0, 0, -5 ] ].each do |c, m, y, k|
      color = Color.new(name: "test", source_space: "cmyk", c: c, m: m, y: y, k: k)
      assert_not color.valid?, "expected cmyk(#{c}, #{m}, #{y}, #{k}) to be rejected"
    end
  end

  test "accepts cmyk channels at the bounds" do
    assert_predicate Color.new(name: "lo", source_space: "cmyk", c: 0, m: 0, y: 0, k: 0), :valid?
    assert_predicate Color.new(name: "hi", source_space: "cmyk", c: 100, m: 100, y: 100, k: 100), :valid?
  end

  test "accepts fractional cmyk channels" do
    assert_predicate Color.new(name: "test", source_space: "cmyk", c: 12.5, m: 0.1, y: 99.9, k: 3), :valid?
  end

  test "requires cmyk channels when the source space is cmyk" do
    color = Color.new(name: "test", source_space: "cmyk")
    assert_not color.valid?
    assert_includes color.errors[:c], "can't be blank"
    assert_includes color.errors[:k], "can't be blank"
  end

  # --- Conversion at write time ------------------------------------------

  test "derives cmyk from rgb on save" do
    color = Color.create!(name: "derived", source_space: "rgb", r: 227, g: 6, b: 19)

    assert_in_delta 0.0, color.c.to_f
    assert_in_delta 97.4, color.m.to_f
    assert_in_delta 91.6, color.y.to_f
    assert_in_delta 11.0, color.k.to_f
  end

  test "derives rgb from cmyk on save" do
    color = Color.create!(name: "derived", source_space: "cmyk", c: 0, m: 100, y: 100, k: 0)

    assert_equal 255, color.r
    assert_equal 0, color.g
    assert_equal 0, color.b
  end

  test "ignores supplied values for the derived space" do
    color = Color.create!(name: "bogus", source_space: "rgb", r: 0, g: 0, b: 0, c: 50, m: 50, y: 50, k: 0)

    assert_in_delta 100.0, color.k.to_f
    assert_in_delta 0.0, color.c.to_f
  end

  test "reconverts when the source values change" do
    color = colors(:signal_red)
    color.update!(r: 0, g: 0, b: 255)

    assert_in_delta 100.0, color.c.to_f
    assert_in_delta 100.0, color.m.to_f
    assert_in_delta 0.0, color.y.to_f
  end

  test "reconverts when the source space itself changes" do
    color = Color.create!(name: "flip", source_space: "cmyk", c: 0, m: 0, y: 0, k: 100)
    assert_equal 0, color.r

    # Now treat it as an RGB colour: RGB becomes the truth and CMYK is redrawn.
    color.update!(source_space: "rgb", r: 255, g: 255, b: 255)
    assert_in_delta 0.0, color.k.to_f
  end

  test "persists both spaces to the database" do
    color = Color.create!(name: "roundtrip", source_space: "rgb", r: 196, g: 132, b: 44)
    reloaded = Color.find(color.id)

    assert_equal [ 196, 132, 44 ], [ reloaded.r, reloaded.g, reloaded.b ]
    assert_in_delta 32.7, reloaded.m.to_f
    assert_in_delta 77.6, reloaded.y.to_f
    assert_in_delta 23.1, reloaded.k.to_f
  end

  # --- Hex ---------------------------------------------------------------

  test "derives hex rather than storing it" do
    assert_equal "#E30613", colors(:signal_red).hex
    assert_not_includes Color.column_names, "hex"
  end

  test "derives hex from the rgb of a cmyk sourced colour" do
    assert_equal "#00FFFF", colors(:process_cyan).hex
  end

  # --- Tags --------------------------------------------------------------

  test "normalizes tags on save" do
    color = Color.create!(name: "tagged", source_space: "rgb", r: 0, g: 0, b: 0,
                          tags: [ "  Brand ", "PRIMARY", "brand" ])

    assert_equal [ "brand", "primary" ], color.tags
  end

  test "drops blank tags" do
    color = Color.create!(name: "tagged", source_space: "rgb", r: 0, g: 0, b: 0,
                          tags: [ "brand", "", "   ", nil ])

    assert_equal [ "brand" ], color.tags
  end

  test "defaults tags to an empty array" do
    assert_equal [], Color.create!(name: "untagged", source_space: "rgb", r: 0, g: 0, b: 0).tags
  end

  test "treats nil tags as empty" do
    assert_equal [], Color.create!(name: "nil tags", source_space: "rgb", r: 0, g: 0, b: 0, tags: nil).tags
  end

  test "accepts a comma separated tag string" do
    color = Color.create!(name: "csv", source_space: "rgb", r: 0, g: 0, b: 0, tags: "Brand, primary")

    assert_equal [ "brand", "primary" ], color.tags
  end

  test "rejects tags that are not a list of strings" do
    color = Color.new(name: "bad", source_space: "rgb", r: 0, g: 0, b: 0, tags: { brand: true })

    assert_not color.valid?
    assert_includes color.errors[:tags], "must be an array of strings"
  end

  test "exposes tags as a display list" do
    assert_equal "brand, primary", colors(:signal_red).tag_list
  end

  # --- Associations ------------------------------------------------------

  test "belongs to many palettes" do
    assert_equal [ "Autumn 2026", "Brand Core" ], colors(:signal_red).palettes.map(&:name).sort
  end

  test "can belong to no palette" do
    assert_empty colors(:deep_indigo).palettes
  end

  test "leaves palettes intact when destroyed but removes its memberships" do
    color = colors(:autumn_ochre)
    palette = palettes(:autumn)

    assert_difference -> { PaletteColor.count }, -1 do
      color.destroy!
    end

    assert Palette.exists?(palette.id)
  end

  # --- Scopes ------------------------------------------------------------

  test "tagged returns colours carrying the tag" do
    assert_equal [ "ink-black", "paper-white", "signal-red" ], Color.tagged("brand").order(:name).pluck(:name)
  end

  test "tagged is case insensitive" do
    assert_equal Color.tagged("brand").pluck(:id).sort, Color.tagged("BRAND").pluck(:id).sort
  end

  test "tagged matches whole tags only" do
    assert_empty Color.tagged("bran")
  end

  test "tagged returns nothing for a blank tag" do
    assert_empty Color.tagged("")
    assert_empty Color.tagged(nil)
  end

  test "by_hex finds an exact rgb match" do
    assert_equal [ colors(:signal_red).id ], Color.by_hex("#E30613").pluck(:id)
  end

  test "by_hex accepts hex without a leading hash and in any case" do
    assert_equal [ colors(:signal_red).id ], Color.by_hex("e30613").pluck(:id)
  end

  test "by_hex returns nothing for an unparseable or unmatched hex" do
    assert_empty Color.by_hex("not-a-hex")
    assert_empty Color.by_hex("#ABCDEF")
    assert_empty Color.by_hex(nil)
  end

  test "in_palette accepts a palette id or name" do
    palette = palettes(:brand)

    assert_equal [ "ink-black", "paper-white", "signal-red" ], Color.in_palette(palette.id).order(:name).pluck(:name)
    assert_equal [ "ink-black", "paper-white", "signal-red" ], Color.in_palette("Brand Core").order(:name).pluck(:name)
  end

  test "all_tags lists every colour tag in use once, in order" do
    assert_equal [ "brand", "cool", "neutral", "primary", "print", "process", "seasonal" ], Color.all_tags
  end

  test "in_palette returns nothing for an unknown palette" do
    assert_empty Color.in_palette("No Such Palette")
  end
end
