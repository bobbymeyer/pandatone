module Pandatone
  module PaletteSerializer
    module_function

    # Collections and embedded references carry the summary; only a palette
    # asked for by itself carries its colors.
    def summary(palette)
      { id: palette.id, name: palette.name, tags: palette.tags }
    end

    def one(palette)
      summary(palette).merge(colors: ColorSerializer.many(palette.colors))
    end

    def many(palettes)
      palettes.map { |palette| summary(palette) }
    end
  end
end
