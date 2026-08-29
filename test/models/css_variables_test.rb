require "test_helper"

class CssVariablesTest < ActiveSupport::TestCase
  test "declares one custom property per swatch, in palette order" do
    css = CssVariables.new(palettes(:brand)).to_s

    assert_equal palettes(:brand).swatches.map { |color| "--#{color.name}" },
      css.scan(/^\s+(--[\w-]+):/).flatten
  end

  test "gives each one the color as a hex" do
    css = CssVariables.new(palettes(:brand)).to_s

    assert_includes css, "--signal-red: #E30613;"
  end

  # CSS has no CMYK, so a color authored in inks goes out as the hex it
  # renders to. Saying so in the file is the honest version of that: the
  # number here is a conversion, not the recipe.
  test "notes a color that was authored in inks" do
    palette = Palette.create!(name: "Process")
    palette.palette_colors.create!(color: colors(:process_cyan), position: 0)

    assert_match(/--process-cyan: #00FFFF; +\/\* from CMYK 100 0 0 0 \*\//,
      CssVariables.new(palette).to_s)
  end

  test "says which palette it came from" do
    assert_match(/\A\/\* Brand Core .* \*\//, CssVariables.new(palettes(:brand)).to_s)
  end

  test "puts them on :root, which is where a custom property is looked for" do
    assert_includes CssVariables.new(palettes(:brand)).to_s, ":root {"
  end

  # A name is free text and a custom property name is not, so the one is
  # turned into the other rather than pasted in and hoped for.
  test "turns a name into something a stylesheet can hold" do
    palette = Palette.create!(name: "Loud")
    palette.palette_colors.create!(
      color: Color.create!(name: "Signal Red (2026)!", source_space: Color::RGB, r: 1, g: 2, b: 3),
      position: 0)

    assert_includes CssVariables.new(palette).to_s, "--signal-red-2026: #010203;"
  end

  # Two colors may carry the same name — only the value is unique — and two
  # identical property names would mean the second silently winning.
  test "keeps two swatches with one name apart" do
    palette = Palette.create!(name: "Twins")
    [ [ 1, 2, 3 ], [ 4, 5, 6 ] ].each_with_index do |(r, g, b), position|
      palette.palette_colors.create!(
        color: Color.create!(name: "red", source_space: Color::RGB, r: r, g: g, b: b),
        position: position)
    end

    assert_equal [ "--red", "--red-2" ], CssVariables.new(palette).to_s.scan(/(--[\w-]+):/).flatten
  end

  # parameterize can return nothing at all, and "--: #000;" is not a rule.
  test "falls back to the value when a name leaves nothing behind" do
    palette = Palette.create!(name: "Nameless")
    palette.palette_colors.create!(
      color: Color.create!(name: "!!!", source_space: Color::RGB, r: 17, g: 34, b: 51),
      position: 0)

    assert_includes CssVariables.new(palette).to_s, "--112233: #112233;"
  end

  test "an empty palette is still a valid stylesheet" do
    css = CssVariables.new(palettes(:empty)).to_s

    assert_includes css, ":root {"
    assert_includes css, "}"
    assert_no_match(/--/, css.sub(/\A\/\*.*\*\//, ""))
  end
end
