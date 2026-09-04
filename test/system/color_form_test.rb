require "application_system_test_case"

module Pandatone
  class ColorFormTest < ApplicationSystemTestCase
    # Writing a color down: the new and edit forms, and the near-duplicate
    # question that stands between the two of them and the library.

    test "creates a color that belongs to no palette yet" do
      visit colors_path
      click_on "New color"

      fill_in "Swatch name", with: "loose-blue"
      choose "Hex"
      fill_in "Hex value", with: "#1E5AAA"
      click_on "Create color"

      assert_text "loose-blue"
      assert_text "#1E5AAA"
      assert_text "No palettes hold this color yet"
    end

    test "reports a bad new color without losing what was typed" do
      visit new_color_path

      fill_in "Swatch name", with: "impossible"
      choose "Hex"
      fill_in "Hex value", with: "not-a-color"
      click_on "Create color"

      assert_text "is not a color we can read"
      assert_equal "impossible", find_field("Swatch name").value
    end

    # paper-white is #FAFAF8. A plain #FFFFFF is 17 apart on the redmean scale:
    # near enough that a library holding both is almost certainly holding one
    # color twice.
    test "asks before adding a color that is nearly one already in the library" do
      visit new_color_path

      fill_in "Swatch name", with: "off-white"
      choose "Hex"
      fill_in "Hex value", with: "#FFFFFF"

      before = Color.count
      click_on "Create color"

      assert_text "This is similar to paper-white"
      assert_text "#FAFAF8"
      assert_selector ".warning .swatch", count: 2
      assert_equal before, Color.count, "nothing should have been written while the question stands"
    end

    test "adds it anyway once the question is answered" do
      visit new_color_path

      fill_in "Swatch name", with: "off-white"
      choose "Hex"
      fill_in "Hex value", with: "#FFFFFF"
      click_on "Create color"

      assert_text "This is similar to paper-white"
      before = Color.count
      click_on "Create anyway"

      assert_no_selector ".warning"
      assert_text "off-white"
      assert_text "#FFFFFF"
      assert_equal before + 1, Color.count
    end

    test "asks again when the color changes after the warning" do
      visit new_color_path

      fill_in "Swatch name", with: "off-white"
      choose "Hex"
      fill_in "Hex value", with: "#FFFFFF"
      click_on "Create color"

      assert_text "This is similar to paper-white"
      fill_in "Hex value", with: "#FDFDFD"

      before = Color.count
      click_on "Create anyway"

      # The old warning is still on screen, so asserting on its wording would
      # pass without the second submission ever landing. Only the re-rendered
      # warning names the color that was just typed.
      within ".warning" do
        assert_text "#FDFDFD"
      end
      assert_equal before, Color.count
    end

    test "refuses an exact duplicate rather than asking about it" do
      visit new_color_path

      fill_in "Swatch name", with: "red again"
      choose "Hex"
      fill_in "Hex value", with: "#E30613"

      before = Color.count
      click_on "Create color"

      assert_text %(#E30613 is already in the library as "signal-red")
      assert_no_text "This is similar to"
      assert_equal before, Color.count
    end

    test "edits a color name and tags" do
      visit color_path(colors(:deep_indigo))
      click_on "Edit color"

      fill_in "Swatch name", with: "night-indigo"
      fill_in "Swatch tags", with: "Cool, brand"
      click_on "Save color"

      assert_text "night-indigo"
      assert_text "cool · brand"
    end

    test "prefills the edit form with what is stored" do
      visit edit_color_path(colors(:signal_red))

      assert_equal "signal-red", find_field("Swatch name").value
      assert_equal "brand, primary", find_field("Swatch tags").value
      assert_equal "227", find_field("R").value
      assert find("#swatch_input_mode_rgb", visible: :all).checked?
    end

    test "opens a cmyk sourced color in cmyk" do
      visit edit_color_path(colors(:process_cyan))

      assert find("#swatch_input_mode_cmyk", visible: :all).checked?
      assert_equal "100.0", find_field("C").value
    end

    test "edits a color by its rgb values" do
      visit edit_color_path(colors(:deep_indigo))

      fill_in "R", with: "213"
      fill_in "G", with: "22"
      fill_in "B", with: "43"
      click_on "Save color"

      # The path, not the hex: the entry row's live preview paints the hex on
      # the form itself, so asserting on it would be satisfied without the save
      # ever having happened.
      assert_current_path color_path(colors(:deep_indigo))
      assert_text "#D5162B"
      assert_equal [ 213, 22, 43 ], colors(:deep_indigo).reload.rgb.values
    end

    test "edits a color by hex" do
      visit edit_color_path(colors(:deep_indigo))

      choose "Hex"
      fill_in "Hex value", with: "#C77A1A"
      click_on "Save color"

      assert_current_path color_path(colors(:deep_indigo))
      assert_text "#C77A1A"
      assert_text "Authored in RGB"
    end

    test "switches a color from rgb to cmyk" do
      visit edit_color_path(colors(:deep_indigo))

      choose "CMYK"
      fill_in "C", with: "0"
      fill_in "M", with: "0"
      fill_in "Y", with: "100"
      fill_in "K", with: "0"
      click_on "Save color"

      assert_text "Authored in CMYK"
      assert_text "#FFFF00"
    end

    test "reports a validation error without losing what was typed" do
      visit edit_color_path(colors(:deep_indigo))

      fill_in "Swatch name", with: ""
      choose "Hex"
      fill_in "Hex value", with: "not-a-color"
      click_on "Save color"

      assert_text "is not a color we can read"
      assert_equal "not-a-color", find_field("Hex value").value
      assert_equal 43, colors(:deep_indigo).reload.r
    end

    test "editing a shared color changes it in every palette holding it" do
      visit edit_color_path(colors(:signal_red))

      fill_in "R", with: "0"
      fill_in "G", with: "0"
      fill_in "B", with: "0"
      click_on "Save color"

      assert_current_path color_path(colors(:signal_red))

      visit palette_path(palettes(:brand))
      assert_selector "#palette_color_#{palette_colors(:brand_signal_red).id} .swatch[style*='#000000']"

      visit palette_path(palettes(:autumn))
      assert_selector "#palette_color_#{palette_colors(:autumn_signal_red).id} .swatch[style*='#000000']"
    end

    test "warns that a shared color is shared" do
      visit edit_color_path(colors(:signal_red))

      assert_text "2 palettes"
    end

    test "reaches the edit form from a palette swatch" do
      visit palette_path(palettes(:brand))
      click_on "signal-red"
      click_on "Edit color"

      assert_equal "signal-red", find_field("Swatch name").value
    end

    test "asks before editing a color into a near duplicate" do
      visit edit_color_path(colors(:deep_indigo))

      choose "Hex"
      fill_in "Hex value", with: "#FFFFFF"
      click_on "Save color"

      assert_text "This is similar to paper-white"
      assert_equal [ 43, 74, 138 ], colors(:deep_indigo).reload.rgb.values

      click_on "Save anyway"

      assert_current_path color_path(colors(:deep_indigo))
      assert_equal [ 255, 255, 255 ], colors(:deep_indigo).reload.rgb.values
    end

    test "says nothing about a color that resembles nothing on file" do
      visit new_color_path

      fill_in "Swatch name", with: "grass"
      choose "Hex"
      fill_in "Hex value", with: "#14A028"

      before = Color.count
      click_on "Create color"

      # Text only the color's own page carries: a path built from
      # Color.find_by would be evaluated before the wait, when the row the
      # request is creating may not exist yet.
      assert_text "No palettes hold this color yet"
      assert_text "#14A028"
      assert_equal before + 1, Color.count
    end
  end
end
