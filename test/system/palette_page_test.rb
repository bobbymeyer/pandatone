require "application_system_test_case"

class PalettePageTest < ApplicationSystemTestCase
  # One palette's own page: its swatches in both spaces, their order, and
  # everything you can do to the palette itself.

  test "shows the chosen swatch in both color spaces" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_signal_red).id)

    assert_text "Brand Core"

    within ".swatch-detail" do
      assert_text "signal-red"
      assert_text "#E30613"
      assert_text "227"       # rgb
      assert_text "97.4"      # cmyk
    end
  end

  test "removes a swatch from a palette but keeps the color in the library" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_ink_black).id)

    within(".swatch-detail") { click_on "Remove" }

    assert_no_text "ink-black"
    assert Color.exists?(colors(:ink_black).id)
  end

  test "refuses to remove a swatch that would leave a duplicate palette" do
    press = palettes(:press)
    PaletteComposition.new(press, attributes: {},
      colors: palettes(:brand).color_ids.map { |id| { id: id } } + [ { id: colors(:process_cyan).id } ]).save

    visit palette_path(press, swatch: press.palette_colors.find_by(color: colors(:process_cyan)).id)

    within(".swatch-detail") { click_on "Remove" }

    assert_text %("Brand Core" already holds exactly these colors)
    assert_equal 4, press.palette_colors.reload.size
  end

  test "moves a swatch later in the palette" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_signal_red).id)

    within(".swatch-detail") { click_on "Down" }

    assert_row "ink-black", "signal-red", "paper-white"
    assert_equal [ "ink-black", "signal-red", "paper-white" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "moves a swatch earlier in the palette" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_paper_white).id)

    within(".swatch-detail") { click_on "Up" }

    assert_row "signal-red", "paper-white", "ink-black"
    assert_equal [ "signal-red", "paper-white", "ink-black" ], palettes(:brand).reload.colors.map(&:name)
  end

  # Moving a swatch is about seeing where it landed, so the page comes back
  # on it rather than on whatever happens to be first.
  test "the moved swatch is still the chosen one" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_signal_red).id)

    within(".swatch-detail") { click_on "Down" }

    assert_selector ".swatch-detail .swatch-name", text: "signal-red"
    assert_selector ".swatch-row > li:nth-child(2).selected"
  end

  test "offers no way to move the first swatch up or the last one down" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_signal_red).id)
    within(".swatch-detail") do
      assert_no_selector "button", text: "Up"
      assert_selector "button", text: "Down"
    end

    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_paper_white).id)
    within(".swatch-detail") do
      assert_selector "button", text: "Up"
      assert_no_selector "button", text: "Down"
    end
  end

  test "moving a swatch leaves the other palettes holding it alone" do
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_signal_red).id)

    within(".swatch-detail") { click_on "Down" }

    assert_row "ink-black", "signal-red", "paper-white"
    assert_equal [ "autumn-ochre", "signal-red" ], palettes(:autumn).reload.colors.map(&:name)
  end

  test "edits palette tags inline" do
    visit palette_path(palettes(:press))

    click_on "Edit tags"
    fill_in "Tags", with: "print, archive"
    click_on "Save tags"

    assert_text "archive"
  end

  test "edits a palette name" do
    visit palette_path(palettes(:press))
    click_on "Edit palette"

    fill_in "Name", with: "Press Check 2027"
    click_on "Save palette"

    assert_text "Press Check 2027"
  end

  test "asks before deleting a palette" do
    visit palette_path(palettes(:press))

    assert_equal "Delete Press Check and its swatch order? The colors stay in the library.",
      find("button", text: "Delete palette")[:"data-turbo-confirm"]
  end

  test "deletes a palette" do
    visit palette_path(palettes(:press))

    confirming { click_on "Delete palette" }

    assert_text "Palettes"
    assert_no_text "Press Check"
    assert Color.exists?(colors(:process_cyan).id)
  end

  # The two places these colors actually go: a design tool, and a stylesheet.
  test "offers the palette as a file, in both formats" do
    visit palette_path(palettes(:brand))

    within(".export") do
      assert_equal [ "ASE", "CSS variables" ], all("a").map(&:text)
    end
  end

  test "each export link asks for the palette in that format" do
    visit palette_path(palettes(:brand))

    paths = within(".export") { all("a").map { |link| URI.parse(link[:href]).path } }

    assert_equal [ "/palettes/#{palettes(:brand).id}.ase", "/palettes/#{palettes(:brand).id}.css" ], paths
  end

  # A palette is one row divided by its own count, at any count. It used to
  # wrap, which made a swatch's size depend on where it fell in the order —
  # and handed the whole of the last row to whatever was left over.
  test "a palette of nine is nine equal parts of one row" do
    needs_a_browser

    palette = Palette.create!(name: "Nine")
    9.times do |i|
      palette.palette_colors.create!(position: i,
        color: Color.create!(name: "nine-#{i}", source_space: Color::RGB, r: 10 * i, g: 60, b: 200))
    end

    visit palette_path(palette)

    widths = widths_of(".swatch-row > li")
    assert_equal 9, widths.size
    assert_equal 1, widths.uniq.size, "the swatches came out #{widths.inspect}"
    assert_equal 1, tops_of(".swatch-row > li").uniq.size, "the row wrapped"
  end

  test "and fills the width whatever that count is" do
    needs_a_browser

    visit palette_path(palettes(:brand))

    widths = widths_of(".swatch-row > li")
    assert_in_delta width_of(".swatch-row"), widths.sum, 2
  end

  # The CSS rule for this existed and did nothing for a while: button_to wraps
  # its button in a form, so the flex child is the form and an auto margin on
  # the button inside it goes nowhere. Only a rendered position proves it.
  test "removing a swatch is set apart from reordering it" do
    needs_a_browser

    # A swatch in the middle of the row, so all three controls are there.
    visit palette_path(palettes(:brand), swatch: palette_colors(:brand_ink_black).id)

    lefts = evaluate_script(
      "Array.from(document.querySelectorAll('.swatch-detail__controls > *'))" \
      ".map(el => Math.round(el.getBoundingClientRect().left))"
    )

    assert_equal 3, lefts.size, "expected up, down and remove"
    reorder_gap = lefts[1] - lefts[0]
    destroy_gap = lefts[2] - lefts[1]

    assert_operator destroy_gap, :>, reorder_gap * 2,
      "remove sits as close to down as down does to up: #{lefts.inspect}"
  end

  # --- Choosing one -------------------------------------------------------

  test "opens on the first swatch" do
    visit palette_path(palettes(:brand))

    assert_selector ".swatch-row > li:first-child.selected"
    assert_selector ".swatch-detail .swatch-name", text: "signal-red"
  end

  test "choosing a swatch shows its own values" do
    visit palette_path(palettes(:brand))

    find(".swatch-row a[aria-label^='paper-white']").click

    assert_selector ".swatch-detail .swatch-name", text: "paper-white"
    assert_text "#FAFAF8"
    assert_no_selector ".swatch-detail .swatch-name", text: "signal-red"
  end

  # In the URL, so a reload keeps it and it can be sent to somebody.
  test "the chosen swatch is in the address" do
    held = palette_colors(:brand_paper_white)

    visit palette_path(palettes(:brand), swatch: held.id)

    assert_selector ".swatch-detail .swatch-name", text: "paper-white"
  end

  test "a swatch that is not in this palette is simply the first one" do
    visit palette_path(palettes(:brand), swatch: "999999")

    assert_selector ".swatch-detail .swatch-name", text: "signal-red"
  end


  test "the page actions sit on one line" do
    needs_a_browser

    visit palette_path(palettes(:brand))

    # Every action on the page, not a count of them: the row has to hold what
    # it is given, and pinning a number only dates the test.
    #
    # Overlap, not a shared top: the primary action is a filled box and the
    # rest are links, so they sit on one line at different heights.
    spans = evaluate_script(
      "Array.from(document.querySelectorAll('.page-actions > *'))" \
      ".map(el => { const r = el.getBoundingClientRect(); return [r.top, r.bottom] })"
    )

    assert_operator spans.size, :>=, 3, "the page actions went missing"
    first_top, first_bottom = spans.first
    spans.each do |top, bottom|
      assert bottom > first_top && top < first_bottom,
        "the actions wrapped onto more than one line: #{spans.inspect}"
    end
  end

  test "tags are edited in place rather than on their own page" do
    needs_a_browser

    visit palette_path(palettes(:press))

    click_on "Edit tags"
    fill_in "Tags", with: "print, archive"
    click_on "Save tags"

    assert_text "archive"
    assert_current_path palette_path(palettes(:press))
  end

  private
    # A waiting assertion rather than a read of what is there right now: after
    # a move the row is being replaced, and `all` on a half-swapped page
    # returns elements that have already been detached from it.
    def assert_row(*names)
      names.each_with_index do |name, index|
        assert_selector %(.swatch-row > li:nth-child(#{index + 1}) a[aria-label^="#{name} "])
      end

      assert_selector ".swatch-row > li", count: names.size
    end
end
