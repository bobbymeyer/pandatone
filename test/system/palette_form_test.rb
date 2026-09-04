require "application_system_test_case"

module Pandatone
  class PaletteFormTest < ApplicationSystemTestCase
    # Making a palette, either from nothing or from one that already exists.

    test "creates a palette with a first swatch in one pass" do
      visit palettes_path
      click_on "New palette"

      fill_in "Name", with: "Winter 2027"
      fill_in "Tags", with: "Seasonal, cool"

      fill_in "Swatch name", with: "frost"
      fill_in "R", with: "200"
      fill_in "G", with: "220"
      fill_in "B", with: "255"

      click_on "Create palette"

      assert_text "Winter 2027"
      assert_text "seasonal"
      assert_text "frost"
      assert_text "#C8DCFF"
    end

    test "creates a palette without a swatch" do
      visit new_palette_path

      fill_in "Name", with: "Later"
      click_on "Create palette"

      assert_text "Later"
      assert_text "No swatches"
    end

    test "reports validation errors when creating a palette" do
      visit new_palette_path

      fill_in "Name", with: ""
      click_on "Create palette"

      assert_text "can't be blank"
    end

    test "reports validation errors from the swatch without losing the palette name" do
      visit new_palette_path

      fill_in "Name", with: "Half Filled"
      fill_in "Swatch name", with: "impossible"
      choose "Hex"
      fill_in "Hex value", with: "not-a-color"

      click_on "Create palette"

      assert_text "Hex is not a color we can read"
      assert_no_text "Colors Hex"
      assert_equal "Half Filled", find_field("Name").value
      assert_not Palette.exists?(name: "Half Filled")
    end

    test "adds a swatch to an existing palette in cmyk" do
      visit palette_path(palettes(:press))
      click_on "Add a swatch"
      choose "New color"

      fill_in "Swatch name", with: "process-magenta"
      choose "CMYK"
      fill_in "C", with: "0"
      fill_in "M", with: "100"
      fill_in "Y", with: "0"
      fill_in "K", with: "0"

      click_on "Add swatch"

      assert_current_path palette_path(palettes(:press)), ignore_query: true
      assert_text "process-magenta"
      assert_text "#FF00FF"
    end

    test "refuses a palette that would hold exactly another palette's colors" do
      palettes(:brand).colors.each do |color|
        visit new_palette_color_path(palettes(:empty), source: "library")
        within "#color_#{color.id}" do
          click_on "Add"
        end
      end

      assert_text %("Brand Core" already holds exactly these colors)
      assert_equal 2, palettes(:empty).palette_colors.reload.size,
        "the swatch that would have completed the duplicate must not have landed"
    end

    # A seasonal variant starts life as last season's palette with one color
    # swapped, and the rule that no two palettes hold the same colors blocks
    # the clone that workflow would otherwise go through. So the fork carries
    # the swatches into the form instead of saving them: what you save is
    # already the palette you meant.
    test "starts a new palette from an existing one, with every swatch carried" do
      visit palette_path(palettes(:brand))
      click_on "New from this"

      assert_field "Name", with: "Brand Core copy"
      assert_selector ".carried-swatch", count: 3
      assert all(".carried-swatch input[type=checkbox]").all?(&:checked?),
        "the swatches come across ticked; the point is to change them, not re-pick them"
    end

    test "forks a palette with a swatch left behind" do
      visit new_palette_path(from: palettes(:brand).id)

      fill_in "Name", with: "Brand Lite"
      uncheck "ink-black"
      click_on "Create palette"

      # Text only the palette's own page carries: a path built from Palette
      # .find_by would be evaluated before the wait, when the row the request
      # is creating may not exist yet.
      assert_selector ".page-title", text: "Brand Lite"
      assert_equal [ "signal-red", "paper-white" ], Palette.find_by(name: "Brand Lite").colors.pluck(:name)
    end

    test "forks a palette with a swatch added and none dropped" do
      visit new_palette_path(from: palettes(:brand).id)

      fill_in "Name", with: "Brand Plus"
      choose "Hex"
      fill_in "Hex value", with: "#1E5AAA"
      fill_in "Swatch name", with: "brand-blue"
      click_on "Create palette"

      assert_selector ".page-title", text: "Brand Plus"
      assert_equal 4, Palette.find_by(name: "Brand Plus").colors.size
    end

    # Keeping everything and adding nothing is the duplicate the rule forbids,
    # and it says so in the same words it uses everywhere else.
    test "refuses a fork that changes nothing" do
      visit new_palette_path(from: palettes(:brand).id)

      fill_in "Name", with: "Brand Core Again"
      click_on "Create palette"

      assert_text %("Brand Core" already holds exactly these colors)
      assert_not Palette.exists?(name: "Brand Core Again")
    end

    test "a refused fork keeps the swatches you had chosen" do
      visit new_palette_path(from: palettes(:brand).id)

      fill_in "Name", with: ""
      uncheck "ink-black"
      click_on "Create palette"

      assert_text "Name can't be blank"
      assert_not find("#carried_#{colors(:ink_black).id}", visible: :all).checked?
      assert find("#carried_#{colors(:signal_red).id}", visible: :all).checked?
    end

    test "forking an empty palette carries nothing and still works" do
      visit new_palette_path(from: palettes(:empty).id)

      fill_in "Name", with: "Also Empty"
      click_on "Create palette"

      assert_selector ".page-title", text: "Also Empty"
      assert_text "No swatches yet"
    end

    test "a plain new palette offers no swatches to carry" do
      visit new_palette_path

      assert_no_selector ".carried-swatch"
      assert_empty find_field("Name").value.to_s
    end
  end
end
