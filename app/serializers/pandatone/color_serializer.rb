# The wire format for a color. Key order here is the key order downstream
# tools see, and a contract test pins it, so treat this file as the interface.
module Pandatone
  module ColorSerializer
    module_function

    def one(color, palettes: false)
      json = {
        id: color.id,
        name: color.name,
        hex: color.hex,
        rgb: color.rgb,
        cmyk: color.cmyk,
        source_space: color.source_space,
        tags: color.tags
      }

      # The reverse lookup: which palette family does this swatch belong to.
      json[:palettes] = PaletteSerializer.many(color.palettes.reorder(:name)) if palettes
      json
    end

    def many(colors)
      colors.map { |color| one(color) }
    end
  end
end
