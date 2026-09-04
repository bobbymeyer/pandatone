require "pandatone/version"
require "pandatone/engine"

# The public interface: what another tool may call, and the only thing it
# may call. Every method here takes plain arguments and returns plain data —
# the same hashes the JSON API sends — so a caller can never hold one of the
# engine's records, and so the same signature could be wrapped in HTTP the
# day this engine is split to its own deploy without touching the caller.
#
#   Pandatone.palette("Brand Core")          # => { id:, name:, tags:, colors: [...] }
#   Pandatone.palettes(tag: "active")        # => [ { id:, name:, tags: }, ... ]
#   Pandatone.colors(in_palette: "Brand Core")
#   Pandatone.lookup("#E30613")              # => { query:, hex:, rgb:, colors:, palettes:, nearest: }
#   Pandatone.tags                           # => { colors: [...], palettes: [...] }
module Pandatone
  # The host's controllers the engine's inherit from. The host's decide who
  # gets in; the engine never has to know what a user is. Set before the
  # engine loads — in an initializer — to point at different ones.
  mattr_accessor :base_controller_class, default: "::ApplicationController"
  mattr_accessor :api_base_controller_class, default: "::ApiController"

  class << self
    # One palette with its colors in order, by id or by name, or nil.
    def palette(key)
      palette = Palette.friendly(key).first
      PaletteSerializer.one(palette) if palette
    end

    # Palette summaries. tag narrows to one tag; containing to palettes
    # holding a color, given as a hex, an RGB triple or a CMYK build; q to a
    # substring of the name. sort is one of Sortable::SORTS.
    def palettes(tag: nil, containing: nil, q: nil, sort: "name")
      palettes = Palette.name_matching(q)
      palettes = palettes.tagged(tag) if tag.present?
      palettes = palettes.containing(containing) if containing.present?

      PaletteSerializer.many(palettes.sorted(sort))
    end

    # Colors. value finds the one color rendering a value, in_palette the
    # colors of a palette, tag and q as above. sort as above.
    def colors(tag: nil, value: nil, in_palette: nil, q: nil, sort: "name")
      colors = Color.name_matching(q)
      colors = colors.tagged(tag) if tag.present?
      colors = colors.by_value(value) if value.present?
      colors = colors.in_palette(in_palette) if in_palette.present?

      ColorSerializer.many(colors.sorted(sort))
    end

    # The colors of one palette, in the palette's own order unless a sort is
    # asked for — that sequence is the thing being published.
    def palette_colors(key, sort: nil)
      palette = Palette.friendly(key).first
      return nil if palette.nil?

      ColorSerializer.many(sort.present? ? palette.colors.sorted(sort) : palette.colors)
    end

    # What a value is, whether the library holds it, which palettes do, and —
    # when it does not — the closest thing on file. nil when the value cannot
    # be read as a hex, an RGB triple or a CMYK build.
    def lookup(query)
      rgb = ColorSpace.parse(query)
      return nil if rgb.nil?

      hex = ColorSpace.to_hex(rgb[:r], rgb[:g], rgb[:b])
      colors = Color.where(rgb).order(:name)
      nearest = Color.nearest_to(rgb) if colors.empty?

      {
        query: query.to_s,
        hex: hex,
        rgb: rgb,
        # Present only when the value was read as a CMYK build, since that
        # conversion is lossy and the match is on the color it renders to.
        build: ColorSpace.build(query),
        colors: ColorSerializer.many(colors),
        palettes: PaletteSerializer.many(Palette.containing(hex).order(:name)),
        nearest: nearest && ColorSerializer.one(nearest)
      }
    end

    # Every tag in use, which is what a client needs to offer the same
    # filtering the interface does.
    def tags
      { colors: Color.all_tags, palettes: Palette.all_tags }
    end

    # The API's description of itself, as a Hash ready to serve as JSON.
    def openapi
      @openapi ||= YAML.safe_load_file(Engine.root.join("config/openapi.yml"))
    end
  end
end
