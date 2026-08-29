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
    color = Color.create!(name: "derived", source_space: "rgb", r: 220, g: 20, b: 60)

    assert_in_delta 0.0, color.c.to_f
    assert_in_delta 90.9, color.m.to_f
    assert_in_delta 72.7, color.y.to_f
    assert_in_delta 13.7, color.k.to_f
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

    # Now treat it as an RGB color: RGB becomes the truth and CMYK is redrawn.
    color.update!(source_space: "rgb", r: 255, g: 255, b: 255)
    assert_in_delta 0.0, color.k.to_f
  end

  test "persists both spaces to the database" do
    color = Color.create!(name: "roundtrip", source_space: "rgb", r: 100, g: 150, b: 200)
    reloaded = Color.find(color.id)

    assert_equal [ 100, 150, 200 ], [ reloaded.r, reloaded.g, reloaded.b ]
    assert_in_delta 50.0, reloaded.c.to_f
    assert_in_delta 25.0, reloaded.m.to_f
    assert_in_delta 21.6, reloaded.k.to_f
  end

  # --- Hex ---------------------------------------------------------------

  test "derives hex rather than storing it" do
    assert_equal "#E30613", colors(:signal_red).hex
    assert_not_includes Color.column_names, "hex"
  end

  test "derives hex from the rgb of a cmyk sourced color" do
    assert_equal "#00FFFF", colors(:process_cyan).hex
  end

  # --- Hex as an input path ----------------------------------------------
  #
  # hex is derived for reading, but it is also how a color arrives from a hex
  # field or the system color picker, both of which are RGB sources.

  test "sets rgb channels from an assigned hex" do
    color = Color.create!(name: "from hex", source_space: "rgb", hex: "#3366CC")

    assert_equal [ 51, 102, 204 ], [ color.r, color.g, color.b ]
    assert_equal "#3366CC", color.hex
  end

  test "derives cmyk from an assigned hex" do
    color = Color.create!(name: "from hex", source_space: "rgb", hex: "#3366CC")

    assert_in_delta 75.0, color.c.to_f
    assert_in_delta 20.0, color.k.to_f
  end

  test "accepts hex without a hash, in any case, and in shorthand" do
    assert_equal "#E30613", Color.new(source_space: "rgb", hex: "e30613").hex
    assert_equal "#FFCC00", Color.new(source_space: "rgb", hex: "#fc0").hex
  end

  test "rejects a hex it cannot read" do
    color = Color.new(name: "bad hex", source_space: "rgb", hex: "nope")

    assert_not color.valid?
    assert_includes color.errors[:hex], "is not a color we can read"
  end

  test "does not complain about a hex that was never given" do
    color = Color.new(name: "plain", source_space: "rgb", r: 1, g: 2, b: 3)

    assert_predicate color, :valid?
    assert_empty color.errors[:hex]
  end

  test "an assigned hex wins over separately assigned rgb channels" do
    color = Color.create!(name: "both", source_space: "rgb", r: 0, g: 0, b: 0, hex: "#3366CC")

    assert_equal [ 51, 102, 204 ], [ color.r, color.g, color.b ]
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

  test "tagged returns colors carrying the tag" do
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

  test "all_tags lists every color tag in use once, in order" do
    assert_equal [ "brand", "cool", "neutral", "primary", "print", "process", "seasonal" ], Color.all_tags
  end

  test "in_palette returns nothing for an unknown palette" do
    assert_empty Color.in_palette("No Such Palette")
  end

  # --- Uniqueness --------------------------------------------------------

  test "refuses a second color with the same value" do
    twin = Color.new(name: "another red", source_space: "rgb", r: 227, g: 6, b: 19)

    assert_not twin.valid?
    assert_includes twin.errors[:base], %(#E30613 is already in the library as "signal-red")
  end

  test "refuses a duplicate however the color was authored" do
    twin = Color.new(name: "cyan again", source_space: "cmyk", c: 100, m: 0, y: 0, k: 0)

    assert_not twin.valid?, "a cmyk recipe landing on an existing color is still that color"
    assert_includes twin.errors[:base], %(#00FFFF is already in the library as "process-cyan")
  end

  test "a color does not collide with itself on re-save" do
    color = colors(:signal_red)
    color.name = "signal red"

    assert color.save, color.errors.full_messages.to_sentence
  end

  test "the database refuses a duplicate value too" do
    assert_raises ActiveRecord::RecordNotUnique do
      Color.insert!({ name: "sneaky", source_space: "rgb", r: 227, g: 6, b: 19,
        c: 0, m: 97.4, y: 91.6, k: 11.0, tags: [] })
    end
  end

  # --- Similarity --------------------------------------------------------

  test "similar_to finds a near-identical color already in the library" do
    near = Color.new(name: "off white", source_space: "rgb", r: 255, g: 255, b: 255)

    assert_equal colors(:paper_white), Color.similar_to(near)
  end

  test "similar_to ignores colors that plainly differ" do
    assert_nil Color.similar_to(Color.new(name: "grass", source_space: "rgb", r: 20, g: 160, b: 40))
  end

  test "similar_to never returns the color itself" do
    assert_nil Color.similar_to(colors(:signal_red))
  end

  test "similar_to returns the nearest when several are close" do
    Color.create!(name: "near white", source_space: "rgb", r: 246, g: 246, b: 244)
    nearer = Color.create!(name: "nearer white", source_space: "rgb", r: 249, g: 249, b: 247)

    assert_equal nearer, Color.similar_to(Color.new(name: "q", source_space: "rgb", r: 248, g: 249, b: 247))
  end

  test "similar_to says nothing about a color with no values yet" do
    assert_nil Color.similar_to(Color.new(name: "blank", source_space: "rgb"))
  end

  # --- Nearest ------------------------------------------------------------

  test "nearest_to returns the closest color in the library" do
    assert_equal colors(:paper_white), Color.nearest_to({ r: 255, g: 255, b: 255 })
  end

  test "nearest_to answers however far off the nearest is" do
    assert_equal colors(:process_cyan), Color.nearest_to({ r: 0, g: 250, b: 250 })
    assert_not_nil Color.nearest_to({ r: 128, g: 0, b: 128 }),
      "nearest has to mean nearest — there is no threshold on this one"
  end

  test "nearest_to returns the exact match when the library holds one" do
    assert_equal colors(:signal_red), Color.nearest_to({ r: 227, g: 6, b: 19 })
  end

  test "nearest_to returns nothing for an empty library" do
    PaletteColor.delete_all
    Color.delete_all

    assert_nil Color.nearest_to({ r: 1, g: 2, b: 3 })
  end

  test "nearest_to searches only the scope it is called on" do
    assert_equal colors(:process_cyan), Color.tagged("print").nearest_to({ r: 255, g: 255, b: 255 })
  end

  # --- Sorting ------------------------------------------------------------

  test "sorts by name by default, and for anything it does not recognize" do
    [ nil, "", "sideways" ].each do |key|
      assert_equal Color.order(:name).pluck(:name), Color.sorted(key).map(&:name),
        "expected #{key.inspect} to fall back to name order"
    end
  end

  test "sorts by date added, newest first" do
    latest = Color.create!(name: "brand new", source_space: "rgb", r: 3, g: 200, b: 90)

    assert_equal latest, Color.sorted("added").first
  end

  test "sorts by date modified, newest first" do
    touched = colors(:autumn_ochre)
    touched.update!(name: "autumn-ochre-ii")

    assert_equal touched, Color.sorted("modified").first
  end

  test "sorts dark first" do
    order = Color.sorted("dark").map(&:name)

    assert_equal "ink-black", order.first
    assert_equal "paper-white", order.last
  end

  test "sorts light first" do
    assert_equal Color.sorted("dark").map(&:name).reverse, Color.sorted("light").map(&:name)
  end

  test "the color sort runs black, then the spectrum, then white" do
    order = Color.sorted("spectrum").map(&:name)

    assert_equal "ink-black", order.first, "the darkest neutral leads"
    assert_equal "paper-white", order.last, "the lightest neutral closes"
    assert_operator order.index("signal-red"), :<, order.index("autumn-ochre"), "red before orange"
    assert_operator order.index("autumn-ochre"), :<, order.index("process-cyan"), "orange before cyan"
    assert_operator order.index("process-cyan"), :<, order.index("deep-indigo"), "cyan before blue"
  end

  # #E30613 is a red that leans a few degrees toward magenta, so on a wheel
  # cut at red it lands at 356 and sorts after violet. The cut sits in the
  # magenta-to-red gap instead, where a linear list has to break anyway.
  test "a red that leans blue still sorts with the reds" do
    order = Color.sorted("spectrum").map(&:name)

    assert_operator order.index("signal-red"), :<, order.index("deep-indigo"),
      "a red sorting after a blue means the wheel was cut in the wrong place"
  end

  test "sorting applies to the scope it is called on" do
    assert_equal [ "process-cyan" ], Color.tagged("print").sorted("spectrum").map(&:name)
  end

  test "every offered sort is one the model answers to" do
    Color::SORTS.each_key do |key|
      assert_equal Color.count, Color.sorted(key).size, "#{key} lost or duplicated rows"
    end
  end
end
