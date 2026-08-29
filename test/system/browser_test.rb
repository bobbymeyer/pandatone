require "application_system_test_case"

# What only a real browser can answer.
#
# The rest of the suite asserts text and selectors, which are true at any
# width — a list crushed into one column of six passes every one of them. That
# is exactly how the palette index shipped collapsed. These measure instead,
# and they only run under SYSTEM_TEST_DRIVER=selenium.
class BrowserTest < ApplicationSystemTestCase
  setup do
    skip "needs a real browser; run with SYSTEM_TEST_DRIVER=selenium" unless javascript_driver?
  end

  # The one rule the whole palette rests on is that the swatches are the only
  # color on the page. An emoji arrives with its own, and which colors depends
  # on whose emoji font renders it — so it is drained here rather than trusted
  # to be monochrome. Asserted on the computed style rather than grepped out
  # of the stylesheet: a rule on the wrong selector reads correctly in the CSS
  # and does nothing on the page.
  test "the panda is drained of color like everything else that is not a swatch" do
    visit root_path

    assert_equal "grayscale(1)",
      evaluate_script("getComputedStyle(document.querySelector('.masthead__panda')).filter")
  end

  # Half the width, which is the whole of what "small" means here. Measured,
  # because the arithmetic that produces it lives in the grid and a card that
  # merely looked smaller would satisfy any assertion about class names.
  test "a small card is half the width of a large one" do
    [ [ colors_path, ".color-card" ], [ palettes_path, ".palette-strip" ] ].each do |path, card|
      visit "#{path}?size=large"
      large = rect_of(card)["width"]

      visit path
      small = rect_of(card)["width"]

      assert_in_delta large / 2.0, small, large / 12.0,
        "#{path}: a small #{card} is #{small}px against #{large}px large, which is not half"
    end
  end

  # Enough colors that a row is a row rather than the whole library: six
  # fixtures already fit on one at either size, which would have agreed that
  # nothing had changed.
  test "small fits twice as many on a row" do
    14.times { |i| Color.create!(name: "filler-#{i}", source_space: Color::RGB, r: i, g: 40 + i, b: 90) }

    visit colors_path(size: "large")
    large = cards_on_the_first_row(".color-card")

    visit colors_path

    assert_equal large * 2, cards_on_the_first_row(".color-card")
  end

  # A button or a link, not both. An underline is what a link wears here — the
  # quiet links in the prose keep it — so a button cannot also wear it and
  # still be telling you which of the two it is.
  test "no button is underlined" do
    [ palette_path(palettes(:brand)), account_path, new_color_path, colors_path ].each do |path|
      visit path

      underlined = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.button'))
          .filter(el => getComputedStyle(el).textDecorationLine !== 'none')
          .map(el => el.textContent.trim() || el.value)
      JS

      assert_empty underlined, "#{path}: these buttons are wearing a link's underline: #{underlined.inspect}"
    end
  end

  # Which leaves them needing to look like something. Every button carries a
  # surface — a filled block or a keyline one — because without the underline
  # a bare word is just a word.
  test "every button is a block rather than a bare word" do
    [ palette_path(palettes(:brand)), account_path, colors_path ].each do |path|
      visit path

      bare = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.button')).filter(el => {
          const style = getComputedStyle(el);
          const filled = style.backgroundColor !== 'rgba(0, 0, 0, 0)';
          const outlined = parseFloat(style.borderTopWidth) > 0;
          return !filled && !outlined;
        }).map(el => el.textContent.trim() || el.value)
      JS

      assert_empty bare, "#{path}: these buttons have neither a fill nor a keyline: #{bare.inspect}"
    end
  end

  # The quiet links in the prose are the other half of the same rule.
  test "a quiet link keeps the underline the buttons gave up" do
    visit palette_path(palettes(:brand))

    assert_equal "underline",
      evaluate_script("getComputedStyle(document.querySelector('.link-quiet')).textDecorationLine")
  end

  # --- Layout ------------------------------------------------------------

  test "the palette results fill the field the filters fill" do
    visit palettes_path

    assert_in_delta width_of(".filters"), width_of(".palette-list"), 1,
      "the results are not spanning the field — something between them and the grid is unplaced"
  end

  test "the color results fill the field the filters fill" do
    visit colors_path

    assert_in_delta width_of(".filters"), width_of(".color-list"), 1
  end

  # At large, which is the size this proportion is: two fields of six. Small
  # is half of it and has its own test.
  test "palette cards sit three to a row on a wide window" do
    visit palettes_path(size: "large")

    tops = tops_of(".palette-strip")
    assert_equal 3, tops.count(tops.first), "expected three cards on the first row, got #{tops.inspect}"
  end

  test "the page head stops short of the right edge" do
    visit palettes_path

    assert width_of(".page-head") < width_of(".filters"),
      "the head should span four fields against the filter bar's six"
  end

  test "no page scrolls sideways" do
    pages.each do |name, path|
      visit path

      overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert overflow <= 1, "#{name} overflows its width by #{overflow}px"
    end
  end

  test "the page actions sit on one line" do
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

  test "channel values never break mid-value" do
    visit palette_path(palettes(:brand))

    # Each channel is one unbreakable unit, so a narrow card wraps between
    # them rather than splitting "K 11.0" across two lines.
    assert_selector ".swatch-detail .channel", minimum: 7
    tops_of(".swatch-detail:first-child .channels dd .channel").each_slice(1) { |t| assert t.first.is_a?(Integer) }
  end

  # --- Behavior the no-JS suite cannot reach ----------------------------

  test "a row of a form does not stretch across the page" do
    visit lookup_path

    # An unbounded row put the field across the whole width and stranded the
    # button against the right edge.
    assert width_of(".form--inline") <= width_of(".page-head"),
      "the inline form is wider than the text column it sits under"
  end

  test "the preview appears only once there is something to preview" do
    visit new_palette_color_path(palettes(:press), source: "new")

    assert_hidden ".preview"

    fill_in "R", with: "227"
    fill_in "G", with: "6"
    fill_in "B", with: "19"

    assert_visible ".preview"
  end

  test "the swatch preview paints as values are typed" do
    visit new_palette_color_path(palettes(:press), source: "new")

    fill_in "R", with: "227"
    fill_in "G", with: "6"
    fill_in "B", with: "19"

    assert_equal "rgb(227, 6, 19)", preview_background
    assert_text "#E30613"
  end

  test "the preview follows a change of space" do
    visit new_palette_color_path(palettes(:press), source: "new")

    choose "CMYK"
    fill_in "C", with: "0"
    fill_in "M", with: "0"
    fill_in "Y", with: "100"
    fill_in "K", with: "0"

    assert_equal "rgb(255, 255, 0)", preview_background
  end

  test "choosing a space shows only that space's fields" do
    visit new_palette_color_path(palettes(:press), source: "new")

    assert_visible "[data-mode='rgb']"
    assert_hidden "[data-mode='cmyk']"
    assert_hidden "[data-mode='hex']"

    choose "Hex"

    assert_hidden "[data-mode='rgb']"
    assert_visible "[data-mode='hex']"
  end

  test "the source switch shows one panel at a time" do
    visit new_palette_color_path(palettes(:press))

    assert_visible "[data-source='library']"
    assert_hidden "[data-source='new']"

    choose "New color"

    assert_hidden "[data-source='library']"
    assert_visible "[data-source='new']"
  end

  # A row of controls added under the search is one declaration away from
  # pushing the search field out of place. This guarded the button beside it
  # too, until the button stopped being there: the live-search controller
  # takes it away as redundant, so in a browser there is nothing left to sit
  # beside. What still collapses is the field.

  test "the search field holds its line" do
    [ colors_path, palettes_path ].each do |path|
      visit path

      # The field against the whole row, not against its own form: the form
      # collapses along with the field, so comparing the two would agree they
      # are fine.
      field = rect_of(".filter-form > .field")
      row = rect_of(".filters")

      assert_operator field["width"], :>, row["width"] / 3, "#{path}: the search field collapsed"
    end
  end

  # Three registers that read as parallel have to line up as parallel. The
  # labels differ in width, so without a shared column their controls start a
  # few pixels apart — and the search was a stacked field above them rather
  # than one of them at all.
  test "search, tags, sort and size are four registers sharing a label column" do
    [ colors_path, palettes_path ].each do |path|
      visit path

      lefts = evaluate_script(<<~JS)
        [
          ['.filters .filter-form > .field > label', '.filters .filter-form > .field > input'],
          ...Array.from(document.querySelectorAll('.filter-row')).map(row =>
            [row.querySelector('.filter-row__label'), row.querySelector('.tag')])
        ].map(pair => pair.map(el =>
          Math.round((typeof el === 'string' ? document.querySelector(el) : el)
            .getBoundingClientRect().left)))
      JS

      assert_equal 4, lefts.size, "#{path}: expected a search, a tag, a sort and a size register"
      assert_equal 1, lefts.map(&:first).uniq.size, "#{path}: labels start in different columns: #{lefts.inspect}"
      assert_equal 1, lefts.map(&:last).uniq.size, "#{path}: controls start in different columns: #{lefts.inspect}"
    end
  end

  test "the sort options sit on one line of their own, below the search" do
    visit colors_path

    field = rect_of(".filter-form > .field")
    sort = rect_of("[data-filter=sort]")

    assert_equal 1, tops_of("[data-filter=sort] li").uniq.size,
      "the sort options wrapped onto more than one line"
    assert_operator sort["top"], :>=, field["top"] + field["height"] - 1,
      "the sort options crowded onto the search line"
    assert_equal 0, evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"),
      "the sort row pushed the page sideways"
  end

  # The tag links live outside the results frame, so an order that only swapped
  # that frame would leave them carrying the old one.
  test "choosing an order keeps it through a tag filter" do
    visit colors_path

    within("[data-filter=sort]") { click_on "Dark" }
    assert_selector ".color-list > li:first-child", text: "ink-black"

    within("[data-filter=tag]") { click_on "brand" }

    assert_selector ".color-list > li", count: 3
    assert_equal [ "ink-black", "signal-red", "paper-white" ],
      all(".color-card__name").map(&:text)
  end

  test "search filters as you type, without pressing Filter" do
    visit palettes_path

    fill_in "Search", with: "autumn"

    assert_text "1 of 4 palettes"
    assert_no_text "Brand Core"
  end

  # Making the hex a button brought a button's own font with it, which a
  # `font: inherit` reset flattened every size modifier to fix.
  test "a hex keeps its size after becoming a button" do
    visit color_path(colors(:signal_red))
    large = font_size_of(".hex--large")

    visit colors_path
    card = font_size_of(".color-card .hex")

    assert_operator large, :>, card, "the large hex is no bigger than one on a card"
  end

  # This is a color tool, so it is the last place that should lean on color
  # alone to say which of a row of choices is current. Computed, not declared:
  # the weight comes from a register shared with eight other selectors, and a
  # stylesheet grep would only ever find where it happens to be written.
  test "the current filter and sort are marked by more than their color" do
    visit colors_path(tag: "brand")

    %w[ tag sort ].each do |register|
      weights = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('[data-filter=#{register}] .tag'))
          .map(el => [el.classList.contains('active'), getComputedStyle(el).fontWeight])
      JS

      active = weights.select(&:first).map(&:last).map(&:to_i)
      rest = weights.reject(&:first).map(&:last).map(&:to_i)

      assert_equal 1, active.size, "expected one current choice in the #{register} register"
      assert_operator active.first, :>, rest.max,
        "the #{register} register marks its current choice by color alone"
    end
  end

  # A channel reads as a name and a number in one breath, so the name carries
  # the weight: computed, not declared, since the two sit inside one element
  # and a rule on the wrong one would look right in the stylesheet.
  test "a channel's name is bolder than its value" do
    visit color_path(colors(:signal_red))

    weights = evaluate_script(<<~JS)
      (() => {
        const channel = document.querySelector('.channels .channel');
        const key = channel.querySelector('.channel__key');
        return [getComputedStyle(key).fontWeight, getComputedStyle(channel).fontWeight,
                getComputedStyle(document.querySelector('.channels dt')).fontWeight];
      })()
    JS

    key, value, space = weights.map(&:to_i)
    assert_operator key, :>, value, "the channel name is no bolder than its value"
    assert_operator space, :>, value, "the space name is no bolder than the values under it"
  end

  test "a channel still holds its name and value on one line" do
    visit color_path(colors(:signal_red))

    assert_equal 1, tops_of(".channels dd:first-of-type .channel:first-child > *").uniq.size
    assert_equal "R 227", find(".channels dd", match: :first).first(".channel").text
  end

  # The clipboard needs a real browser, a secure origin and a granted
  # permission, so this is the only place the copying itself can be proven.
  test "clicking a hex copies it" do
    grant_clipboard
    visit color_path(colors(:signal_red))

    find(".copy", match: :first).click

    assert_selector ".copy[data-copied]"
    assert_equal "#E30613", evaluate_async_script(
      "navigator.clipboard.readText().then(arguments[0])"
    )
  end

  # No assertion that the confirmation appeared: it clears itself after 1.2s,
  # so asserting its presence is a race against its own timer that a slow
  # machine loses — which is how this failed on CI and never here. That it
  # appears is the previous test's job; this one is only about it going away.
  test "the confirmation clears itself" do
    grant_clipboard
    visit color_path(colors(:signal_red))

    find(".copy", match: :first).click

    assert_no_selector ".copy[data-copied]", wait: 5
  end

  test "a refused clipboard leaves the value readable" do
    visit color_path(colors(:signal_red))

    # No permission granted: the copy fails, and the page must not break or
    # claim to have copied anything.
    find(".copy", match: :first).click

    assert_no_selector ".copy[data-copied]"
    assert_text "#E30613"
  end

  test "tags are edited in place rather than on their own page" do
    visit palette_path(palettes(:press))

    click_on "Edit tags"
    fill_in "Tags", with: "print, archive"
    click_on "Save tags"

    assert_text "archive"
    assert_current_path palette_path(palettes(:press))
  end

  private
    def cards_on_the_first_row(selector)
      evaluate_script(<<~JS)
        (() => {
          const cards = Array.from(document.querySelectorAll('#{selector}'));
          const top = Math.round(cards[0].getBoundingClientRect().top);
          return cards.filter(c => Math.round(c.getBoundingClientRect().top) === top).length;
        })()
      JS
    end

    def pages
      {
        "palette index" => palettes_path,
        "palette show" => palette_path(palettes(:brand)),
        "palette form" => new_palette_path,
        "color index" => colors_path,
        "color show" => color_path(colors(:signal_red)),
        "color form" => new_color_path,
        "add a swatch" => new_palette_color_path(palettes(:press)),
        "lookup" => lookup_path(q: "#E30613")
      }
    end

    def preview_background
      evaluate_script(
        "getComputedStyle(document.querySelector('[data-swatch-preview-target=\"preview\"]')).backgroundColor"
      )
    end
end
