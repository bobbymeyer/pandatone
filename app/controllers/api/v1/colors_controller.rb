module Api
  module V1
    class ColorsController < BaseController
      def index
        colors = Color.order(:name)
        colors = colors.tagged(params[:tag]) if params[:tag].present?
        colors = colors.by_hex(params[:hex]) if params[:hex].present?
        colors = colors.in_palette(params[:palette]) if params[:palette].present?

        render json: ColorSerializer.many(colors)
      end

      def show
        render json: ColorSerializer.one(Color.find(params[:id]), palettes: true)
      end

      def create
        color = Color.new(color_attributes)

        if color.save
          render json: ColorSerializer.one(color, palettes: true), status: :created
        else
          render_invalid(color)
        end
      end

      def update
        color = Color.find(params[:id])

        if color.update(color_attributes)
          render json: ColorSerializer.one(color, palettes: true)
        else
          render_invalid(color)
        end
      end

      private
        def color_attributes
          attributes = color_params.permit(:name, :source_space, :r, :g, :b, :c, :m, :y, :k, tags: []).to_h
          attributes[:tags] = color_params[:tags] if color_params[:tags].is_a?(String)
          attributes
        end

        def color_params
          params.require(:color)
        end
    end
  end
end
