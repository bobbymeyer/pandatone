require "application_system_test_case"

module Pandatone
  class ColorIndexTest < ApplicationSystemTestCase
    # The library itself: what the index lists, how it is narrowed, and the
    # order it comes back in.

    test "lists every color in the library as a swatch" do
      visit colors_path

      assert_selector ".color-card", count: 6

      within "#color_#{colors(:signal_red).id}" do
        assert_text "signal-red"
        assert_text "#E30613"
        assert_selector ".swatch[style*='#E30613']"
      end
    end

    test "shows on the index which palettes each color sits in" do
      visit colors_path

      within "#color_#{colors(:signal_red).id}" do
        assert_text "Brand Core"
        assert_text "Autumn 2026"
      end
    end

    test "says on the index when a color sits in no palette" do
      visit colors_path

      within "#color_#{colors(:deep_indigo).id}" do
        assert_text "No palettes"
      end
    end

    test "a color card is one link to the color, not two to the same place" do
      visit colors_path

      within "#color_#{colors(:signal_red).id}" do
        # href comes back absolute in a browser and raw under rack_test.
        paths = all("a").map { |link| URI.parse(link[:href]).path }
        assert_equal 1, paths.count(color_path(colors(:signal_red))),
          "the swatch and the name are one link between them, not two"
      end
    end

    # Tags on a card look like the tags in the filter bar because they are the
    # same thing, so they behave like them rather than being inert text wearing
    # a control's clothes.
    test "a card's tags filter the library" do
      visit colors_path

      within("#color_#{colors(:signal_red).id}") { click_on "primary" }

      assert_selector "[data-filter=tag] .tag.active", text: "primary", exact_text: true
      assert_equal [ "signal-red" ], card_names
    end

    test "reaches a color from the index" do
      visit colors_path

      within "#color_#{colors(:autumn_ochre).id}" do
        click_on "autumn-ochre"
      end

      assert_text "#C4842C"
      assert_text "Autumn 2026"
    end

    test "counts the matches, not the library, when filtered" do
      visit colors_path

      fill_in "Search", with: "ink"
      filter_unless_live

      assert_text "1 of 6 colors"
    end

    test "filters the color index by tag" do
      visit colors_path

      within("[data-filter=tag]") { click_on "print" }

      assert_text "process-cyan"
      assert_no_text "signal-red"
    end

    test "searches the color index by name" do
      visit colors_path

      fill_in "Search", with: "ink"
      filter_unless_live

      assert_text "ink-black"
      assert_no_text "signal-red"
    end

    test "says so when the color search matches nothing" do
      visit colors_path

      fill_in "Search", with: "nothing-matches-this"
      filter_unless_live

      assert_text "No colors"
    end

    test "combines the color tag filter with a search" do
      visit colors_path

      within("[data-filter=tag]") { click_on "brand" }
      assert_text "3 of 6 colors"

      fill_in "Search", with: "ink"
      filter_unless_live

      assert_text "ink-black"
      assert_no_text "paper-white"
    end

    test "an empty library reads as empty, not as a failed search" do
      Palette.destroy_all
      Color.destroy_all

      visit colors_path

      assert_text "No colors yet"
      assert_no_text "No colors match"
    end

    test "an empty result reads as a failed search" do
      visit colors_path

      fill_in "Search", with: "nothing-matches-this"
      filter_unless_live

      assert_text "No colors match"
      assert_no_text "No colors yet"
    end

    test "lists colors by name until asked otherwise" do
      visit colors_path

      assert_equal Color.order(:name).pluck(:name), card_names
      assert_selector "[data-filter=sort] .tag.active", text: "Name", exact_text: true
    end

    test "sorts by color, dark first and light first" do
      visit colors_path

      sort_by "Dark", leading: "ink-black"
      sort_by "Light", leading: "paper-white"
      sort_by "Color", leading: "ink-black"

      assert_equal "paper-white", card_names.last, "the lightest neutral closes the spectrum"
    end

    test "sorts by date added and date modified" do
      latest = Color.create!(name: "brand new", source_space: "rgb", r: 3, g: 200, b: 90)
      colors(:autumn_ochre).update!(tags: [ "seasonal", "warm" ])

      visit colors_path

      sort_by "Added", leading: latest.name
      sort_by "Modified", leading: "autumn-ochre"
    end

    test "a sort survives a tag filter" do
      visit colors_path

      sort_by "Dark", leading: "ink-black"
      within("[data-filter=tag]") { click_on "brand" }

      assert_selector ".color-list > li", count: 3
      assert_equal [ "ink-black", "signal-red", "paper-white" ], card_names
      assert_selector "[data-filter=sort] .tag.active", text: "Dark", exact_text: true
    end

    test "a search keeps the sort it was run under" do
      visit colors_path

      sort_by "Light", leading: "paper-white"
      fill_in "Search", with: "process"
      filter_unless_live

      assert_selector ".color-list > li", count: 1
      assert_equal [ "process-cyan" ], card_names
      assert_selector "[data-filter=sort] .tag.active", text: "Light", exact_text: true
    end

    # The tag links live outside the results frame, so an order that only swapped
    # that frame would leave them carrying the old one.
    test "choosing an order keeps it through a tag filter" do
      needs_a_browser

      visit colors_path

      within("[data-filter=sort]") { click_on "Dark" }
      assert_selector ".color-list > li:first-child", text: "ink-black"

      within("[data-filter=tag]") { click_on "brand" }

      assert_selector ".color-list > li", count: 3
      assert_equal [ "ink-black", "signal-red", "paper-white" ],
        all(".color-card__name").map(&:text)
    end
  end
end
