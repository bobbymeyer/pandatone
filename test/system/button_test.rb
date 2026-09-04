require "application_system_test_case"

module Pandatone
  # A button or a link, not both. This is the rule the whole set of controls
  # rests on, and it is only true on a rendered page: the underline comes off a
  # register shared with a dozen selectors, so a stylesheet grep proves nothing
  # about the button in front of you.
  class ButtonTest < ApplicationSystemTestCase
    # A button or a link, not both. An underline is what a link wears here — the
    # quiet links in the prose keep it — so a button cannot also wear it and
    # still be telling you which of the two it is.
    test "no button is underlined" do
      needs_a_browser

      [ palette_path(palettes(:brand)), new_color_path, colors_path ].each do |path|
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
      needs_a_browser

      [ palette_path(palettes(:brand)), colors_path ].each do |path|
        visit path

        bare = evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('.button')).filter(el => {
            const style = getComputedStyle(el);
            const filled = style.backgroundColor !== 'rgba(0, 0, 0, 0)';
            // its-swiss draws a keyline as an inset shadow, so the box is the
            // label's line and two paddings and nothing else.
            const outlined = parseFloat(style.borderTopWidth) > 0 || style.boxShadow !== 'none';
            return !filled && !outlined;
          }).map(el => el.textContent.trim() || el.value)
        JS

        assert_empty bare, "#{path}: these buttons have neither a fill nor a keyline: #{bare.inspect}"
      end
    end

    # The quiet links in the prose are the other half of the same rule.
    test "a quiet link keeps the underline the buttons gave up" do
      needs_a_browser

      visit palette_path(palettes(:brand))

      assert_equal "underline",
        evaluate_script("getComputedStyle(document.querySelector('.link-quiet')).textDecorationLine")
    end
  end
end
