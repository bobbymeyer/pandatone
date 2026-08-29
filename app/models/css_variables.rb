# A palette as custom properties, which is how these colors reach a
# stylesheet. The whole file is a header, `:root`, and one declaration per
# swatch in the order the palette holds them.
#
# CSS has no CMYK, so a color authored in inks goes out as the hex it renders
# to and says so in a comment. That conversion is lossy and it is not this
# file's place to pretend otherwise.
class CssVariables
  def initialize(palette)
    @palette = palette
  end

  def to_s
    <<~CSS
      /* #{palette.name} — exported from Pandatone */
      :root {
      #{declarations.join("\n")}
      }
    CSS
  end

  private
    attr_reader :palette

    def declarations
      names = Hash.new(0)

      palette.swatches.map do |color|
        name = distinct(property_name(color), names)

        "  --#{name}: #{color.hex};#{provenance(color)}"
      end
    end

    # A color name is free text; a custom property name is not. parameterize
    # can also come back empty — "!!!" leaves nothing — and `--: #000` is not
    # a rule, so the value names itself in that case.
    def property_name(color)
      color.name.parameterize.presence || color.hex.delete("#")
    end

    # Only the value is unique across colors, so two swatches may arrive
    # carrying one name. Two identical properties would mean the second
    # silently winning, which is worse than an ugly suffix.
    def distinct(name, seen)
      seen[name] += 1

      seen[name] > 1 ? "#{name}-#{seen[name]}" : name
    end

    def provenance(color)
      return "" if color.rgb_source?

      inks = color.cmyk.values.map { |ink| ink.round(1).to_s.delete_suffix(".0") }

      "  /* from CMYK #{inks.join(' ')} */"
    end
end
