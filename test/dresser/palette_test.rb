require "test_helper"

module Pandatone
  class Dresser::PaletteTest < ActiveSupport::TestCase
    # Lightest first, and slot 0 is the ground. its-swiss numbers its own
    # value scale the same way round, so a thing dressed by rank reads the way
    # the library it is dressed in reads.
    test "colours rank lightest first" do
      assert_equal [ "#FAF8F4", "#808080", "#12120F" ], dresser_palette("#12120F", "#FAF8F4", "#808080").ranked.map(&:hex)
    end

    test "ranking is by how light a colour looks, not by its channels" do
      assert_equal [ "#FFFF00", "#0000FF" ], dresser_palette("#0000FF", "#FFFF00").ranked.map(&:hex)
    end

    # A colorway resolves its slots against these ranks every time it renders.
    # Two colours of equal lightness that swapped places between renders
    # would move a slot for no reason anyone could see.
    test "ranking is settled when two colours weigh the same" do
      palette = dresser_palette("#FF0000", "#FF0000", "#FF0000")

      assert_equal [ 700, 701, 702 ], palette.ranked.map(&:id)
    end

    test "a palette serves a thing when it has a colour for every slot" do
      palette = dresser_palette("#000000", "#FFFFFF", "#808080")

      assert palette.serves?(3)
      assert palette.serves?(2)
      assert_not palette.serves?(4)
    end

    test "a palette cycles cleanly when its size divides the stripe count" do
      palette = dresser_palette("#000000", "#FFFFFF", "#808080")

      assert palette.cycles_cleanly?(6)
      assert_not palette.cycles_cleanly?(4)
      assert_not dresser_palette.cycles_cleanly?(6), "an empty palette cycles nothing"
    end

    # The wire format, with either kind of key: what the API sends and what a
    # host with Pandatone in the same process hands over.
    test "reads the wire format with either kind of key" do
      symbols = Dresser::Palette.from_json(id: 1, name: "One", colors: [ { id: 9, name: "c", hex: "#123456", rgb: { r: 0x12, g: 0x34, b: 0x56 } } ])
      strings = Dresser::Palette.from_json("id" => 1, "name" => "One", "colors" => [ { "id" => 9, "name" => "c", "hex" => "#123456" } ])

      assert_equal [ "#123456" ], symbols.colors.map(&:hex)
      assert_equal [ 0x12, 0x34, 0x56 ], symbols.colors.first.channels
      assert_equal [ 0x12, 0x34, 0x56 ], strings.colors.first.channels, "a colour with only a hex still has channels"
    end

    # Identity and value together: two palettes can hold the same hex under
    # different ids, and for anything that names a position those are not
    # interchangeable.
    test "a colour is the same colour by id and hex" do
      assert_equal Dresser::Color.new(id: 1, name: "a", hex: "#000000"), Dresser::Color.new(id: 1, name: "b", hex: "#000000")
      assert_not_equal Dresser::Color.new(id: 1, name: "a", hex: "#000000"), Dresser::Color.new(id: 2, name: "a", hex: "#000000")
    end
  end
end
