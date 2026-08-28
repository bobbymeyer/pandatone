module Api
  module V1
    class PalettesController < BaseController
      before_action :set_palette, only: %i[ show colors update destroy ]

      def index
        palettes = Palette.order(:name)
        palettes = palettes.tagged(params[:tag]) if params[:tag].present?
        palettes = palettes.containing_hex(params[:color]) if params[:color].present?

        render json: PaletteSerializer.many(palettes)
      end

      def show
        render json: PaletteSerializer.one(@palette)
      end

      # The workhorse endpoint for consuming tools.
      def colors
        render json: ColorSerializer.many(@palette.colors)
      end

      def create
        palette = Palette.new
        composition = PaletteComposition.new(palette, attributes: palette_attributes, colors: colors_attributes)

        if composition.save
          render json: PaletteSerializer.one(palette.reload), status: :created
        else
          render_invalid(palette)
        end
      end

      def update
        composition = PaletteComposition.new(@palette, attributes: palette_attributes, colors: colors_attributes)

        if composition.save
          render json: PaletteSerializer.one(@palette.reload)
        else
          render_invalid(@palette)
        end
      end

      def destroy
        @palette.destroy!
        head :no_content
      end

      private
        def set_palette
          @palette = Palette.friendly_find(params[:id])
        end

        def palette_attributes
          attributes = permitted.slice(:name, :tags).to_h
          # The model accepts a comma-separated string too; strong parameters
          # would otherwise drop it silently.
          attributes[:tags] = palette_params[:tags] if palette_params[:tags].is_a?(String)
          attributes
        end

        # nil means "leave the colours alone"; an array, including an empty
        # one, replaces the whole list in the order given.
        def colors_attributes
          permitted[:colors] if palette_params.key?(:colors)
        end

        def permitted
          @permitted ||= palette_params.permit(
            :name,
            tags: [],
            colors: [ :id, :name, :source_space, :r, :g, :b, :c, :m, :y, :k, { tags: [] } ]
          )
        end

        def palette_params
          params.require(:palette)
        end
    end
  end
end
