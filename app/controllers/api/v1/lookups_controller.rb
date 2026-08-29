module Api
  module V1
    # What the lookup screen answers, in one call: what this value is, whether
    # the library holds it, which palettes do, and — when it does not — the
    # closest thing on file.
    class LookupsController < BaseController
      def show
        rgb = ColorSpace.parse(params[:q])
        return render_unreadable if rgb.nil?

        hex = ColorSpace.to_hex(rgb[:r], rgb[:g], rgb[:b])
        colors = Color.where(rgb).order(:name)

        render json: {
          query: params[:q].to_s,
          hex: hex,
          rgb: rgb,
          # Present only when the value was read as a CMYK build, since that
          # conversion is lossy and the match is on the color it renders to.
          build: ColorSpace.build(params[:q]),
          colors: ColorSerializer.many(colors),
          palettes: PaletteSerializer.many(Palette.containing(hex).order(:name)),
          nearest: nearest_to(rgb, unless_matched: colors)
        }
      end

      private
        def nearest_to(rgb, unless_matched:)
          return nil if unless_matched.any?

          nearest = Color.nearest_to(rgb)
          ColorSerializer.one(nearest) if nearest
        end

        def render_unreadable
          render json: { errors: { q: [ "is not a hex, an RGB triple or a CMYK build" ] } },
            status: :unprocessable_content
        end
    end
  end
end
