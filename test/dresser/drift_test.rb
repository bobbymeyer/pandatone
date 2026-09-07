require "test_helper"

module Pandatone
  class Dresser::DriftTest < ActiveSupport::TestCase
    setup do
      @wearer = Wearer.create!(name: "Awning", slot_count: 2)
      @colorway = @wearer.colorways.create!(palette: dresser_palette("#FAF8F4", "#12120F", id: 2, name: "Deck Chair"))
    end

    # Reported, never applied. A design that was finished should not change
    # because someone else opened another tool.
    test "a palette that has moved is reported, and the snapshot is left alone" do
      with_palette_source({ [ 2, "Deck Chair" ] => %w[ #FAF8F4 #000000 ] }) do
        assert_match(/Deck Chair has moved in Pandatone since this snapshot\. Nothing here has changed\./, Dresser::Drift.report(@colorway))
      end

      assert_equal %w[ #FAF8F4 #12120F ], @colorway.reload.snapshot.palette.colors.map(&:hex)
    end

    test "a palette that has not moved says so too" do
      with_palette_source({ [ 2, "Deck Chair" ] => %w[ #FAF8F4 #12120F ] }) do
        assert_equal "Deck Chair is as it was when this snapshot was taken.", Dresser::Drift.report(@colorway)
      end
    end

    test "a palette that is gone from Pandatone says that" do
      with_palette_source({ [ 1, "Two Tone" ] => %w[ #FFFFFF #101010 ] }) do
        assert_match(/no longer has that palette/, Dresser::Drift.report(@colorway))
      end
    end

    # Asked for, so it asks afresh rather than reading a catalogue fetched
    # before the palette moved.
    test "asking forgets the catalogue first" do
      with_palette_source({ [ 2, "Deck Chair" ] => %w[ #FAF8F4 #12120F ] }) do
        Dresser::Catalog.current
        Pandatone::Dresser.source = -> { [ wire_palette(2, "Deck Chair", %w[ #FAF8F4 #000000 ]) ] }

        assert_match(/has moved/, Dresser::Drift.report(@colorway))
      end
    end
  end
end
