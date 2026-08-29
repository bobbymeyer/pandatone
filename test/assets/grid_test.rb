require "test_helper"

# The layout is one modular grid: the page field and every list of cards share
# a single track definition, so a card edge is always a field line. Three
# independent auto-fill grids used to sit alongside it, agreeing with the
# field and with each other only by accident. These pin the decision.
class GridTest < ActiveSupport::TestCase
  STYLESHEETS = Rails.root.glob("app/assets/stylesheets/*.css").freeze

  test "no stylesheet invents its own column count" do
    offenders = STYLESHEETS.select { |sheet| sheet.read.match?(/auto-fill|auto-fit/) }

    assert_empty offenders.map { |sheet| sheet.basename.to_s },
      "auto-fill/auto-fit sizes tracks from available width, which cannot line up with the field"
  end

  test "the column tracks are declared exactly once" do
    declarations = STYLESHEETS.sum { |sheet| sheet.read.scan(/grid-template-columns:\s*repeat\(/).size }

    assert_equal 1, declarations,
      "the field should be defined in one place and shared, not restated per component"
  end

  test "every grid derives its tracks from the column count" do
    repeats = STYLESHEETS.flat_map { |sheet| sheet.read.scan(/grid-template-columns:\s*repeat\(([^,]+),/) }.flatten

    assert_equal [ "var(--columns)" ], repeats
  end

  test "nothing is set in capitals" do
    offenders = STYLESHEETS.select { |sheet| sheet.read.match?(/text-transform:\s*uppercase/) }

    assert_empty offenders.map { |sheet| sheet.basename.to_s },
      "capitals are not used in this interface; size and colour carry the micro register"
  end

  test "leading and spacing come from one ladder" do
    type = Rails.root.join("app/assets/stylesheets/type.css").read

    assert_no_match(/--lead-/, type, "leading should draw on the spacing ladder, not a second one")
    assert_match(/line-height: var\(--space-/, type)
  end

  test "the measure is derived from the field" do
    grid = Rails.root.join("app/assets/stylesheets/grid.css").read

    assert_match(/--measure:\s*calc\(/, grid)
    assert_no_match(/--measure:\s*[\d.]+rem/, grid, "a hand-picked measure lands between field lines")
  end

  test "cards span whole fields rather than fixed widths" do
    grid = Rails.root.join("app/assets/stylesheets/grid.css").read

    assert_match(/--columns:\s*6/, grid)
    assert_match(/grid-column:\s*span var\(--card\)/, grid)
    assert_match(/grid-column:\s*span var\(--card-wide\)/, grid)
  end
end
