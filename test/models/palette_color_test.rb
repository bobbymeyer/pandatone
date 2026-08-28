require "test_helper"

class PaletteColorTest < ActiveSupport::TestCase
  test "requires a palette and a colour" do
    membership = PaletteColor.new

    assert_not membership.valid?
    assert_includes membership.errors[:palette], "must exist"
    assert_includes membership.errors[:color], "must exist"
  end

  test "requires a non negative integer position" do
    membership = PaletteColor.new(palette: palettes(:empty), color: colors(:deep_indigo), position: -1)

    assert_not membership.valid?
    assert_includes membership.errors[:position], "must be greater than or equal to 0"
  end

  test "holds a colour in a palette at a position" do
    membership = palette_colors(:brand_signal_red)

    assert_equal palettes(:brand), membership.palette
    assert_equal colors(:signal_red), membership.color
    assert_equal 0, membership.position
  end

  test "rejects the same colour twice in one palette" do
    duplicate = PaletteColor.new(palette: palettes(:brand), color: colors(:signal_red), position: 9)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:color_id], "has already been taken"
  end

  test "allows the same colour in different palettes" do
    assert_predicate PaletteColor.new(palette: palettes(:press), color: colors(:signal_red)), :valid?
  end
end
