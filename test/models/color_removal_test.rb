require "test_helper"

class ColorRemovalTest < ActiveSupport::TestCase
  test "deletes a color no palette holds" do
    color = colors(:deep_indigo)

    assert_difference "Color.count", -1 do
      assert ColorRemoval.new(color).destroy, color.errors.full_messages.to_sentence
    end
  end

  # Deleting a shared color quietly rewrites every palette holding it, which
  # is a much larger act than the button says. So it is refused until asked
  # for in those terms.
  test "refuses a color a palette holds, and names the palettes" do
    color = colors(:signal_red)

    assert_no_difference "Color.count" do
      assert_not ColorRemoval.new(color).destroy
    end

    assert_includes color.errors[:base],
      %(signal-red is in Autumn 2026 and Brand Core. Delete it from those palettes too if you mean to remove it.)
  end

  test "deletes a held color when that is what was asked for" do
    color = colors(:signal_red)

    assert_difference "Color.count", -1 do
      assert ColorRemoval.new(color, from_palettes: true).destroy, color.errors.full_messages.to_sentence
    end

    assert_equal [ "ink-black", "paper-white" ], palettes(:brand).colors.reload.order(:name).pluck(:name)
    assert_equal [ "autumn-ochre" ], palettes(:autumn).colors.reload.pluck(:name)
  end

  test "leaves the palettes alone when the deletion is refused" do
    ColorRemoval.new(colors(:signal_red)).destroy

    assert_equal 3, palettes(:brand).palette_colors.reload.size
  end

  # The rule that no two palettes hold the same colors cannot be true only on
  # the way in: a cascade that quietly makes two palettes identical breaks it
  # just as thoroughly as saving a duplicate would.
  test "refuses a deletion that would leave two palettes identical" do
    pair = Palette.new
    PaletteComposition.new(pair, attributes: { name: "Pair" },
      colors: [ { id: colors(:signal_red).id }, { id: colors(:ink_black).id } ]).save

    color = colors(:paper_white)

    assert_no_difference "Color.count" do
      assert_not ColorRemoval.new(color, from_palettes: true).destroy
    end

    assert_includes color.errors[:base],
      %(Deleting this would leave "Brand Core" and "Pair" holding exactly the same colors.)
  end

  test "empty palettes left behind do not count as duplicates" do
    color = colors(:process_cyan)

    assert_difference "Color.count", -1 do
      assert ColorRemoval.new(color, from_palettes: true).destroy, color.errors.full_messages.to_sentence
    end

    assert_empty palettes(:press).palette_colors.reload,
      "Press Check held only that color, so it is left empty rather than refused"
  end

  test "closes the gap in the positions of the palettes it strips" do
    ColorRemoval.new(colors(:ink_black), from_palettes: true).destroy

    assert_equal [ 0, 1 ], palettes(:brand).palette_colors.reload.pluck(:position)
  end
end
