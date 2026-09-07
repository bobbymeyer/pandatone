require "test_helper"

module Pandatone
  # The concerns, worn by the dummy host's Wearer: something with ranked
  # slots, a colorway, a snapshot and a rule per slot. Its tables are the
  # host's, the way a consumer's are.
  class Dresser::ColorwayTest < ActiveSupport::TestCase
    setup { @wearer = Wearer.create!(name: "Awning", slot_count: 2) }

    test "choosing a palette takes a snapshot of it, and the colours resolve by rank" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4", "#C1272D"))

      assert_equal 7, colorway.palette_id
      assert_equal "Sample", colorway.palette_name
      assert_equal 3, colorway.snapshot.size
      assert_equal %w[ #FAF8F4 #12120F ], colorway.colors, "the lightest is the ground and the darkest is the last slot"
    end

    # p > n, so the ranks are sampled. Both ends are kept: the ground stays the
    # lightest colour the palette has and the last slot the darkest, which is
    # the range the palette was chosen for.
    test "a palette with more colours than slots is sampled evenly by rank" do
      six = %w[ #FFFFFF #DDDDDD #BBBBBB #999999 #555555 #000000 ]

      assert_equal %w[ #FFFFFF #000000 ], colors_of(2, six)
      assert_equal %w[ #FFFFFF #999999 #000000 ], colors_of(3, six)
      assert_equal six, colors_of(6, six)
    end

    test "a palette with fewer colours than slots is refused" do
      colorway = @wearer.colorways.build(palette: dresser_palette("#12120F"))

      assert_not colorway.valid?
      assert_equal [ "has 1 colours for 2 slots" ], colorway.errors[:palette]
    end

    # Kept and marked, never deleted: the thing grew a slot the palette cannot
    # fill, and the colorway is still the record of a decision someone made.
    test "a thing that outgrows its palette invalidates the colorway without losing it" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#FAF8F4", "#12120F"))

      @wearer.update!(slot_count: 3)

      assert_predicate colorway.reload, :invalidated?
      assert_equal [], colorway.colors

      @wearer.update!(slot_count: 2)
      assert_not_predicate colorway.reload, :invalidated?
    end

    test "destroying the thing takes its colorways, snapshots and rules with it" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#FAF8F4", "#12120F"))
      colorway.bind(1, kind: "assigned_slot", slot: 0)

      assert_difference [ "Wearer::Colorway.count", "Wearer::PaletteSnapshot.count", "Wearer::Rule.count" ], -1 do
        @wearer.destroy!
      end
    end

    # --- The snapshot --------------------------------------------------------

    test "a snapshot rebuilds a palette that ranks the way the original did" do
      snapshot = snapshot_of("#12120F", "#FAF8F4", "#808080")

      assert_equal [ "#FAF8F4", "#808080", "#12120F" ], snapshot.palette.ranked.map(&:hex)
      assert_equal 7, snapshot.palette.id
      assert_not_nil snapshot.taken_at
    end

    # The point of holding colours rather than a palette id. Pandatone has its
    # own editor, and a colorway that re-fetched on every render would change
    # under a design that was finished.
    test "a colour edited, added, removed or moved in Pandatone is drift" do
      snapshot = snapshot_of("#FAF8F4", "#12120F")

      assert_not snapshot.drifted_from?(dresser_palette("#FAF8F4", "#12120F"))
      assert snapshot.drifted_from?(dresser_palette("#FAF8F4", "#111111")), "edited"
      assert snapshot.drifted_from?(dresser_palette("#FAF8F4", "#12120F", "#808080")), "added"
      assert snapshot.drifted_from?(dresser_palette("#FAF8F4")), "removed"

      original = dresser_palette("#FAF8F4", "#12120F")
      reordered = Dresser::Palette.new(id: original.id, name: original.name, colors: original.colors.reverse)
      assert snapshot.drifted_from?(reordered), "moved: an assigned slot names a position"
    end

    test "drift is flagged and not applied" do
      snapshot = snapshot_of("#FAF8F4", "#12120F")

      snapshot.drifted_from?(dresser_palette("#FF0000", "#00FF00"))

      assert_equal [ "#FAF8F4", "#12120F" ], snapshot.reload.palette.colors.map(&:hex)
    end

    # --- The rule -----------------------------------------------------------

    test "a slot with nothing said about it is bound to its rank" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4"))

      assert_predicate colorway.rule_for(0), :auto_value_match?
      assert_predicate colorway.rule_for(0), :binds_to_rank?
    end

    # palette[i], and i is where the colour sits in the palette — not where it
    # sits once ranked. Drift is order-sensitive for exactly this reason.
    test "an assigned slot reads the palette's own order" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4", "#808080"))

      colorway.bind(0, kind: "assigned_slot", slot: 0)

      assert_equal "#12120F", colorway.reload.colors.first
      assert_not colorway.rule_for(0).binds_to_rank?
    end

    test "an assigned slot must name a colour the palette has" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4", "#808080"))

      assert_raises(ActiveRecord::RecordInvalid) { colorway.bind(0, kind: "assigned_slot", slot: 3) }
      assert_raises(ActiveRecord::RecordInvalid) { colorway.bind(0, kind: "assigned_slot", slot: -1) }
      assert_nothing_raised { colorway.bind(0, kind: "assigned_slot", slot: 2) }
    end

    test "a kind the consumer has not declared is refused" do
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4"))

      assert_raises(ActiveRecord::RecordInvalid) { colorway.bind(0, kind: "random", subset: [ 0 ]) }
    end

    # A consumer with more kinds says so, and the predicates follow.
    test "a consumer extends the kinds" do
      extended = Class.new(Wearer::Rule) do
        def self.name = "Wearer::WiderRule"
        KINDS = (Pandatone::Dresser::Rule::KINDS + %w[ increment ]).freeze
        def self.kinds = KINDS
        kind_predicates "increment"
      end
      colorway = @wearer.colorways.create!(palette: dresser_palette("#12120F", "#FAF8F4"))
      rule = extended.new(colorway: colorway, rank: 0, kind: "increment")

      assert_predicate rule, :increment?
      assert_predicate rule, :valid?
    end

    private
      def colors_of(slot_count, hexes)
        Wearer.create!(name: "Of #{slot_count}", slot_count: slot_count)
          .colorways.create!(palette: dresser_palette(*hexes)).colors
      end

      def snapshot_of(*hexes)
        @wearer.colorways.create!(palette: dresser_palette(*hexes)).snapshot
      end
  end
end
