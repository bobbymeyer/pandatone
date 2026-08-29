module Api
  module V1
    class ColorsController < BaseController
      def index
        colors = Color.all
        colors = colors.tagged(params[:tag]) if params[:tag].present?
        colors = colors.by_hex(params[:hex]) if params[:hex].present?
        colors = colors.in_palette(params[:palette]) if params[:palette].present?

        render json: ColorSerializer.many(colors.sorted(sort_key))
      end

      def show
        render json: ColorSerializer.one(Color.find(params[:id]), palettes: true)
      end

      def create
        color = Color.new(color_attributes)
        twin = unconfirmed_twin(color)
        return render_too_similar(twin) if twin

        if color.save
          render json: ColorSerializer.one(color, palettes: true), status: :created
        else
          render_invalid(color)
        end
      end

      def update
        color = Color.find(params[:id])
        color.assign_attributes(color_attributes)
        twin = unconfirmed_twin(color)
        return render_too_similar(twin) if twin

        if color.save
          render json: ColorSerializer.one(color, palettes: true)
        else
          render_invalid(color)
        end
      end

      # Deleting a shared color rewrites every palette holding it, so a client
      # has to say that is what it means: pass from_palettes.
      def destroy
        color = Color.find(params[:id])

        if ColorRemoval.new(color, from_palettes: boolean(params[:from_palettes])).destroy
          head :no_content
        else
          render_invalid(color)
        end
      end

      private
        def boolean(value)
          ActiveModel::Type::Boolean.new.cast(value)
        end

        # The same near-duplicate check the interface makes, in the shape a
        # client can act on: refused with the swatch it resembles attached, and
        # accepted on a second call carrying confirm_similar. Silently letting
        # machines fill the library with colors no human would have added
        # would make the rule decorative.
        def unconfirmed_twin(color)
          return nil if boolean(params[:confirm_similar])
          return nil unless color.valid?

          Color.similar_to(color)
        end

        def render_too_similar(twin)
          render json: {
            errors: { base: [ %(too similar to "#{twin.name}" (#{twin.hex}); resend with confirm_similar to add it anyway) ] },
            similar: ColorSerializer.one(twin)
          }, status: :unprocessable_content
        end

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
