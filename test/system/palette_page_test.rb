require "application_system_test_case"

class PalettePageTest < ApplicationSystemTestCase
  # One palette's own page: its swatches in both spaces, their order, and
  # everything you can do to the palette itself.

  test "shows a palette with every swatch in both color spaces" do
    visit palette_path(palettes(:brand))

    assert_text "Brand Core"

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      assert_text "signal-red"
      assert_text "#E30613"
      assert_text "227"       # rgb
      assert_text "97.4"      # cmyk
    end
  end

  test "removes a swatch from a palette but keeps the color in the library" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_ink_black).id}" do
      click_on "Remove"
    end

    assert_no_text "ink-black"
    assert Color.exists?(colors(:ink_black).id)
  end

  test "refuses to remove a swatch that would leave a duplicate palette" do
    press = palettes(:press)
    PaletteComposition.new(press, attributes: {},
      colors: palettes(:brand).color_ids.map { |id| { id: id } } + [ { id: colors(:process_cyan).id } ]).save

    visit palette_path(press)

    within "#palette_color_#{press.palette_colors.find_by(color: colors(:process_cyan)).id}" do
      click_on "Remove"
    end

    assert_text %("Brand Core" already holds exactly these colors)
    assert_equal 4, press.palette_colors.reload.size
  end

  test "moves a swatch later in the palette" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      click_on "Down"
    end

    assert_selector ".swatch-grid > li:first-child .swatch-name", text: "ink-black"
    assert_equal [ "ink-black", "signal-red", "paper-white" ], all(".swatch-detail .swatch-name").map(&:text)
    assert_equal [ "ink-black", "signal-red", "paper-white" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "moves a swatch earlier in the palette" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_paper_white).id}" do
      click_on "Up"
    end

    assert_selector ".swatch-grid > li:nth-child(2) .swatch-name", text: "paper-white"
    assert_equal [ "signal-red", "paper-white", "ink-black" ], all(".swatch-detail .swatch-name").map(&:text)
    assert_equal [ "signal-red", "paper-white", "ink-black" ], palettes(:brand).reload.colors.map(&:name)
  end

  test "offers no way to move the first swatch up or the last one down" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      assert_no_selector "button", text: "Up"
      assert_selector "button", text: "Down"
    end

    within "#palette_color_#{palette_colors(:brand_paper_white).id}" do
      assert_selector "button", text: "Up"
      assert_no_selector "button", text: "Down"
    end
  end

  test "moving a swatch leaves the other palettes holding it alone" do
    visit palette_path(palettes(:brand))

    within "#palette_color_#{palette_colors(:brand_signal_red).id}" do
      click_on "Down"
    end

    assert_selector ".swatch-grid > li:first-child .swatch-name", text: "ink-black"
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
end
