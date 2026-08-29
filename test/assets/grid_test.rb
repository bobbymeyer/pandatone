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
      "capitals are not used in this interface; size and color carry the micro register"
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

  # --- Type ----------------------------------------------------------------

  # A label is a label wherever it stands. The filter block's two new ones
  # came out a step larger than the choices they label, which is backwards,
  # and a step larger than every other label in the app.
  test "every register label is set in the one micro register" do
    # The rule that uses the micro size and tracks it, not the :root block
    # that declares the size.
    selectors = type[/([^{}]+)\{[^}]*font-size:\s*var\(--size-1\)[^}]*letter-spacing[^}]*\}/m, 1]

    assert selectors, "expected one rule setting the micro register"
    [ ".field label", ".filter-row__label", ".mode-toggle legend", ".source-toggle legend" ].each do |label|
      assert_includes selectors, label,
        "#{label} is not in the micro register, so it is set differently from every other label"
    end
  end

  # --- Signals -------------------------------------------------------------

  # This is a color tool, so it is the last place that should lean on color
  # alone to say which of a row of choices is current.
  test "the current filter and sort are marked by more than their color" do
    rule = components[/\.tag\.active\s*\{([^}]*)\}/m, 1]

    assert rule, "expected a .tag.active rule"
    assert_match(/font-weight/, rule,
      "the active state is color and nothing else, which is invisible to a reader who cannot see it")
  end

  test "the destructive register is not the quiet one" do
    assert_match(/\.button--danger[^{]*\{/, components, "expected destructive actions to have their own class")
    assert_match(/\.button--danger:hover,\s*\.button--danger:focus-visible/, components,
      "the danger register has to answer focus as well as hover")
  end

  # Hover cannot be the only thing that separates reordering from destroying:
  # a reader scanning the row has not hovered anything yet.
  test "destructive actions are set apart at rest, not only on hover" do
    [ ".swatch-detail__controls", ".page-actions" ].each do |region|
      rule = components[/#{Regexp.escape(region)}[^{]*button--danger[^{]*\{([^}]*)\}/m, 1]

      assert rule, "expected #{region} to set its destructive action apart"
      assert_match(/margin/, rule, "#{region} separates them by color alone")
    end
  end

  test "the copy affordance answers focus as well as hover" do
    assert_match(/\.hex--copy:focus-visible::after/, components,
      "a keyboard reaches the copy button and touch never hovers")
  end

  private
    def components
      @components ||= File.read(Rails.root.join("app/assets/stylesheets/components.css"))
    end

    def type
      @type ||= File.read(Rails.root.join("app/assets/stylesheets/type.css"))
    end
end
