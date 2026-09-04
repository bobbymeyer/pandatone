require "application_system_test_case"

module Pandatone
  class ColorDeletionTest < ApplicationSystemTestCase
    # Taking a color out of the library, and what its palettes have to say
    # about that.

    test "deletes a color no palette holds" do
      visit color_path(colors(:deep_indigo))

      confirming { click_on "Delete color" }

      assert_current_path colors_path
      assert_no_text "deep-indigo"
      assert_not Color.exists?(colors(:deep_indigo).id)
    end

    # The confirmation is the last place to say what deleting a shared color
    # will actually do, so it names the palettes rather than asking twice.
    test "names the palettes before deleting a color they hold" do
      visit color_path(colors(:signal_red))

      assert_equal "signal-red is in Autumn 2026 and Brand Core. Delete it and take it out of those palettes?",
        find_button("Delete color")[:"data-turbo-confirm"]
    end

    test "deletes a shared color out of every palette holding it" do
      visit color_path(colors(:signal_red))

      confirming { click_on "Delete color" }

      assert_current_path colors_path
      assert_equal [ "ink-black", "paper-white" ], palettes(:brand).colors.reload.order(:name).pluck(:name)
    end

    test "refuses a deletion that would leave two palettes identical" do
      pair = Palette.new
      PaletteComposition.new(pair, attributes: { name: "Pair" },
        colors: [ { id: colors(:signal_red).id }, { id: colors(:ink_black).id } ]).save

      visit color_path(colors(:paper_white))
      confirming { click_on "Delete color" }

      assert_text %(Deleting this would leave "Brand Core" and "Pair" holding exactly the same colors)
      assert Color.exists?(colors(:paper_white).id)
    end
  end
end
