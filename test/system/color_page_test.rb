require "application_system_test_case"

class ColorPageTest < ApplicationSystemTestCase
  # One color's own page: both spaces, the palettes holding it, its tags,
  # and the hex you came for.

  test "shows a color in both spaces with the palettes that hold it" do
    visit color_path(colors(:signal_red))

    assert_text "signal-red"
    assert_text "#E30613"
    assert_text "227"
    assert_text "97.4"
    assert_text "brand"
    assert_text "Brand Core"
    assert_text "Autumn 2026"
  end

  test "marks which space a color was authored in" do
    visit color_path(colors(:process_cyan))

    assert_text "CMYK"
    assert_text "approximate"
  end

  test "shows a color that belongs to no palette" do
    visit color_path(colors(:deep_indigo))

    assert_text "deep-indigo"
    assert_text "No palettes"
  end

  # A name alone does not tell you what the palette is. Rendering each one as
  # its own strip shows the company the color keeps.
  test "shows each related palette as a strip of its swatches" do
    visit color_path(colors(:signal_red))

    within "#palette_#{palettes(:brand).id}" do
      assert_text "Brand Core"
      assert_selector ".swatch", count: 3
      assert_selector ".swatch[style*='#111111']"
    end

    within "#palette_#{palettes(:autumn).id}" do
      assert_text "Autumn 2026"
      assert_selector ".swatch", count: 2
      assert_selector ".swatch[style*='#C4842C']"
    end
  end

  test "links from a color through to a palette that holds it" do
    visit color_path(colors(:signal_red))

    within "#palette_#{palettes(:brand).id}" do
      click_on "Brand Core"
    end

    assert_selector ".swatch-row li", count: 3
    assert_selector ".swatch-detail", text: "signal-red"
  end

  test "reaches a color from the palette it sits in" do
    visit palette_path(palettes(:autumn))

    click_on "autumn-ochre"

    assert_text "#C4842C"
    assert_text "Autumn 2026"
  end

  test "edits a color's tags in place" do
    visit color_path(colors(:deep_indigo))

    click_on "Edit tags"
    fill_in "Tags", with: "Cool, brand"
    click_on "Save tags"

    assert_current_path color_path(colors(:deep_indigo))
    assert_text "cool · brand"
  end

  test "says so rather than showing nothing when a color has no tags" do
    colors(:deep_indigo).update!(tags: [])

    visit color_path(colors(:deep_indigo))

    assert_text "Untagged"
  end

  # A hex is on screen to be taken somewhere else, so it is a button. The
  # value stays readable inside it, which is what keeps the page usable when
  # the clipboard is not.
  test "every hex on screen is a copy button carrying its own value" do
    visit color_path(colors(:signal_red))

    button = find(".copy", match: :first)
    assert_equal "#E30613", button.text
    assert_equal "#E30613", button["data-its-swiss-clipboard-text-value"]
    assert_equal "Copy #E30613", button["aria-label"]
  end

  test "hexes are copy buttons on the index and the lookup too" do
    visit colors_path
    assert_selector ".color-card .copy", minimum: 6

    visit lookup_path(q: "#E30613")
    assert_selector ".copy", text: "#E30613"
  end

  # Making the hex a button brought a button's own font with it, which a
  # `font: inherit` reset flattened every size modifier to fix.
  test "a hex keeps its size after becoming a button" do
    needs_a_browser

    visit color_path(colors(:signal_red))
    large = font_size_of(".hex--large")

    visit colors_path
    card = font_size_of(".color-card .hex")

    assert_operator large, :>, card, "the large hex is no bigger than one on a card"
  end

  # A channel reads as a name and a number in one breath, so the name carries
  # the weight: computed, not declared, since the two sit inside one element
  # and a rule on the wrong one would look right in the stylesheet.
  test "a channel's name is bolder than its value" do
    needs_a_browser

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
    needs_a_browser

    visit color_path(colors(:signal_red))

    assert_equal 1, tops_of(".channels dd:first-of-type .channel:first-child > *").uniq.size
    assert_equal "R 227", find(".channels dd", match: :first).first(".channel").text
  end

  # The clipboard needs a real browser, a secure origin and a granted
  # permission, so this is the only place the copying itself can be proven.
  test "clicking a hex copies it" do
    needs_a_browser

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
    needs_a_browser

    grant_clipboard
    visit color_path(colors(:signal_red))

    find(".copy", match: :first).click

    assert_no_selector ".copy[data-copied]", wait: 5
  end

  test "a refused clipboard leaves the value readable" do
    needs_a_browser

    visit color_path(colors(:signal_red))

    # No permission granted: the copy fails, and the page must not break or
    # claim to have copied anything.
    find(".copy", match: :first).click

    assert_no_selector ".copy[data-copied]"
    assert_text "#E30613"
  end
end
