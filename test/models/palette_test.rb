require "test_helper"

class PaletteTest < ActiveSupport::TestCase
  # --- Validations -------------------------------------------------------

  test "is valid with a name" do
    assert_predicate Palette.new(name: "Winter 2027"), :valid?
  end

  test "requires a name" do
    palette = Palette.new
    assert_not palette.valid?
    assert_includes palette.errors[:name], "can't be blank"
  end

  test "rejects a blank name" do
    palette = Palette.new(name: "   ")
    assert_not palette.valid?
    assert_includes palette.errors[:name], "can't be blank"
  end

  test "requires a unique name" do
    palette = Palette.new(name: "Brand Core")
    assert_not palette.valid?
    assert_includes palette.errors[:name], "has already been taken"
  end

  test "compares names case insensitively for uniqueness" do
    palette = Palette.new(name: "brand core")
    assert_not palette.valid?
    assert_includes palette.errors[:name], "has already been taken"
  end

  test "enforces uniqueness in the database as well as the model" do
    assert_raises ActiveRecord::RecordNotUnique do
      Palette.insert!({ name: "brand CORE", tags: "[]", created_at: Time.current, updated_at: Time.current })
    end
  end

  test "strips surrounding whitespace from the name" do
    assert_equal "Winter 2027", Palette.create!(name: "  Winter 2027  ").name
  end

  # --- Tags --------------------------------------------------------------

  test "normalizes tags on save" do
    palette = Palette.create!(name: "Tagged", tags: [ " Seasonal ", "ACTIVE", "seasonal" ])

    assert_equal [ "seasonal", "active" ], palette.tags
  end

  test "defaults tags to an empty array" do
    assert_equal [], Palette.create!(name: "Untagged").tags
  end

  test "accepts a comma separated tag string" do
    assert_equal [ "seasonal", "active" ], Palette.create!(name: "CSV", tags: "Seasonal, ACTIVE").tags
  end

  test "rejects tags that are not a list of strings" do
    palette = Palette.new(name: "Bad", tags: 42)

    assert_not palette.valid?
    assert_includes palette.errors[:tags], "must be an array of strings"
  end

  test "exposes tags as a display list" do
    assert_equal "brand, active", palettes(:brand).tag_list
  end

  # --- Associations ------------------------------------------------------

  test "has colors in position order" do
    assert_equal [ "signal-red", "ink-black", "paper-white" ], palettes(:brand).colors.map(&:name)
  end

  test "orders colors by position regardless of insertion order" do
    palette = Palette.create!(name: "Reordered")
    palette.palette_colors.create!(color: colors(:ink_black), position: 5)
    palette.palette_colors.create!(color: colors(:signal_red), position: 1)

    assert_equal [ "signal-red", "ink-black" ], palette.reload.colors.map(&:name)
  end

  test "can have no colors" do
    assert_empty palettes(:empty).colors
  end

  test "destroys its memberships but not the colors themselves" do
    palette = palettes(:brand)

    assert_difference -> { PaletteColor.count }, -3 do
      assert_no_difference -> { Color.count } do
        palette.destroy!
      end
    end

    assert Color.exists?(colors(:signal_red).id)
  end

  test "shares a color with other palettes rather than copying it" do
    assert_includes palettes(:brand).colors, colors(:signal_red)
    assert_includes palettes(:autumn).colors, colors(:signal_red)
  end

  # --- Positions ---------------------------------------------------------

  test "assigns the next position when one is not given" do
    palette = palettes(:brand)
    membership = palette.palette_colors.create!(color: colors(:deep_indigo))

    assert_equal 3, membership.position
  end

  test "starts positions at zero for an empty palette" do
    membership = palettes(:empty).palette_colors.create!(color: colors(:deep_indigo))

    assert_equal 0, membership.position
  end

  # --- Scopes ------------------------------------------------------------

  test "tagged returns palettes carrying the tag" do
    assert_equal [ "Autumn 2026", "Brand Core" ], Palette.tagged("active").order(:name).pluck(:name)
  end

  test "tagged is case insensitive" do
    assert_equal Palette.tagged("active").pluck(:id).sort, Palette.tagged("Active").pluck(:id).sort
  end

  test "tagged matches whole tags only" do
    assert_empty Palette.tagged("act")
  end

  test "tagged returns nothing for a blank tag" do
    assert_empty Palette.tagged(nil)
  end

  test "containing_hex finds every palette holding that exact color" do
    assert_equal [ "Autumn 2026", "Brand Core" ], Palette.containing_hex("#E30613").order(:name).pluck(:name)
  end

  test "containing_hex accepts hex without a leading hash and in any case" do
    assert_equal [ "Autumn 2026", "Brand Core" ], Palette.containing_hex("e30613").order(:name).pluck(:name)
  end

  test "containing_hex returns each palette once" do
    palettes(:brand).palette_colors.create!(color: colors(:deep_indigo))

    assert_equal 1, Palette.containing_hex("#2B4A8A").count
  end

  test "containing_hex returns nothing for an unparseable or unmatched hex" do
    assert_empty Palette.containing_hex("not-a-hex")
    assert_empty Palette.containing_hex("#ABCDEF")
    assert_empty Palette.containing_hex(nil)
  end

  test "scopes combine" do
    assert_equal [ "Autumn 2026" ], Palette.tagged("seasonal").containing_hex("#E30613").pluck(:name)
  end

  test "name_matching finds palettes by partial name" do
    assert_equal [ "Autumn 2026" ], Palette.name_matching("autumn").pluck(:name)
    assert_equal [ "Autumn 2026" ], Palette.name_matching("AUTUMN").pluck(:name)
    assert_equal [ "Brand Core" ], Palette.name_matching("core").pluck(:name)
  end

  test "name_matching treats wildcards as literal characters" do
    assert_empty Palette.name_matching("%")
    assert_empty Palette.name_matching("_utumn")
  end

  test "name_matching returns everything for a blank term" do
    assert_equal Palette.count, Palette.name_matching("").count
    assert_equal Palette.count, Palette.name_matching(nil).count
  end

  test "all_tags lists every tag in use once, in order" do
    assert_equal [ "active", "brand", "print", "seasonal" ], Palette.all_tags
  end

  test "all_tags is empty when nothing is tagged" do
    Palette.find_each { |palette| palette.update!(tags: []) }

    assert_empty Palette.all_tags
  end

  # --- Friendly lookup ---------------------------------------------------

  test "finds by id" do
    assert_equal palettes(:brand), Palette.friendly_find(palettes(:brand).id)
  end

  test "finds by name when the id does not resolve" do
    assert_equal palettes(:brand), Palette.friendly_find("Brand Core")
  end

  test "finds by name case insensitively" do
    assert_equal palettes(:brand), Palette.friendly_find("brand core")
  end

  test "raises when nothing matches" do
    assert_raises ActiveRecord::RecordNotFound do
      Palette.friendly_find("No Such Palette")
    end
  end

  test "raises for a blank lookup" do
    assert_raises ActiveRecord::RecordNotFound do
      Palette.friendly_find(nil)
    end
  end

  # --- Sorting ------------------------------------------------------------

  test "sorts by name by default, and for anything it does not recognise" do
    [ nil, "", "sideways" ].each do |key|
      assert_equal Palette.order(:name).pluck(:name), Palette.sorted(key).map(&:name),
        "expected #{key.inspect} to fall back to name order"
    end
  end

  test "sorts by date added and date modified, newest first" do
    latest = Palette.create!(name: "Just Made")

    assert_equal latest, Palette.sorted("added").first

    palettes(:press).update!(tags: [ "print", "archive" ])
    assert_equal palettes(:press), Palette.sorted("modified").first
  end

  # A palette is dark or light as a whole, not at its first swatch, so this
  # averages: Press Check is one bright cyan, Autumn is an ochre and a red.
  test "sorts dark first and light first by the average of its swatches" do
    assert_equal [ "Autumn 2026", "Brand Core", "Press Check" ],
      Palette.sorted("dark").map(&:name).first(3)

    assert_equal [ "Press Check", "Brand Core", "Autumn 2026" ],
      Palette.sorted("light").map(&:name).first(3)
  end

  # A hue cannot be averaged — the mean of red and violet is green — so the
  # color sort reads the swatch the strip leads with.
  test "the color sort reads the swatch each palette leads with" do
    assert_equal [ "Brand Core", "Autumn 2026", "Press Check" ],
      Palette.sorted("spectrum").map(&:name).first(3)
  end

  test "a palette with no swatches sorts last, whichever way the color runs" do
    %w[ spectrum dark light ].each do |key|
      assert_equal "Unfilled", Palette.sorted(key).map(&:name).last,
        "expected the empty palette to sort last under #{key}"
    end
  end

  test "sorting applies to the scope it is called on" do
    assert_equal [ "Press Check" ], Palette.tagged("print").sorted("dark").map(&:name)
  end

  test "every offered sort is one the model answers to" do
    Palette::SORTS.each_key do |key|
      assert_equal Palette.count, Palette.sorted(key).size, "#{key} lost or duplicated rows"
    end
  end
end
