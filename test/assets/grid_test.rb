require "test_helper"

# The grid is this app's and the primitives under it are its-swiss's. What is
# left to guard here is what a library cannot know: how many fields this
# problem has, how many of them a card takes, and the second density the two
# indexes offer.
#
# The tokens, the type ladder, the destructive register and the copy
# affordance are guarded in the library's own suite now. A guard on someone
# else's file is a guard that goes stale without ever failing, so they are
# gone rather than repeated.
class GridTest < ActiveSupport::TestCase
  STYLESHEETS = Rails.root.glob("app/assets/stylesheets/*.css").freeze

  test "no stylesheet invents its own column count" do
    offenders = STYLESHEETS.select { |sheet| sheet.read.match?(/repeat\(\s*auto-(?:fill|fit)/) }

    assert_empty offenders.map { |sheet| sheet.basename.to_s },
      "auto-fill/auto-fit sizes tracks from available width, which cannot line up with the field"
  end

  # Two densities, not two grids: the library's field, and the same field
  # halved for the small size on the indexes. They are named counts declared
  # beside each other, which is what keeps a card edge on a field line at
  # either one — and repeat() takes an integer and not an expression, so the
  # two can only be kept in step by hand.
  test "the field count and the density that doubles it are declared together" do
    assert_match(/--columns:\s*6/, theme)
    assert_match(/--columns-dense:\s*12/, theme)
  end

  # A field is a run of equal tracks — repeat(). A two-column label and value
  # grid is not a field and is nobody's business but its component's.
  test "the second density is the only run of tracks this app declares" do
    repeats = STYLESHEETS.to_h do |sheet|
      [ sheet.basename.to_s, sheet.read.scan(/grid-template-columns:\s*repeat\(([^,]+),/).flatten ]
    end

    assert_equal({ "grid.css" => %w[ var(--columns-dense) ] }, repeats.reject { |_, found| found.empty? },
      "the field itself is .grid's, and a second density belongs in grid.css rather than per component")
  end

  test "cards span whole fields rather than fixed widths" do
    assert_match(/--card:\s*\d/, theme)
    assert_match(/--card-wide:\s*\d/, theme)
    assert_match(/--span:\s*var\(--card\)/, grid)
    assert_match(/--span:\s*var\(--card-wide\)/, grid)
  end

  test "nothing is set in capitals" do
    offenders = STYLESHEETS.select { |sheet| sheet.read.match?(/text-transform:\s*uppercase/) }

    assert_empty offenders.map { |sheet| sheet.basename.to_s },
      "capitals are not used in this interface; size and value carry the micro register"
  end

  # A label is a label wherever it stands. The filter block's two came out a
  # step larger than the choices they label, which is backward, and a step
  # larger than every other label in the app.
  #
  # its-swiss sets bare label and legend in the micro register, so every
  # control's own label is the library's and guarded there. These two are
  # spans, which no library can know about, so they are what is left to name.
  test "every register label is set in the one micro register" do
    selectors = type[/([^{}]+)\{[^}]*font-size:\s*var\(--size-1\)[^}]*letter-spacing[^}]*\}/m, 1]

    assert selectors, "expected one rule setting the micro register"
    [ ".filter-row__label", ".export__label" ].each do |label|
      assert_includes selectors, label,
        "#{label} is not in the micro register, so it is set differently from every other label"
    end
  end

  private
    def grid = sheet("grid")

    def theme = sheet("theme")

    def type = sheet("type")

    def sheet(name)
      (@sheets ||= {})[name] ||= Rails.root.join("app/assets/stylesheets/#{name}.css").read
    end
end
