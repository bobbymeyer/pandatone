module Palettes
  class ColorsController < ApplicationController
    before_action :set_palette

    def new
    end

    def create
      spec = swatch_spec

      if spec.nil?
        @palette.errors.add(:colors, "need a name and some values")
        return render :new, status: :unprocessable_content
      end

      if PaletteComposition.new(@palette, attributes: {}, append: [ spec ]).save
        redirect_to @palette
      else
        render :new, status: :unprocessable_content
      end
    end

    # Removes the swatch from this palette only. The colour stays in the
    # library, because it may well sit in other palettes.
    def destroy
      @palette.palette_colors.find_by!(color_id: params[:id]).destroy!
      redirect_to @palette
    end

    private
      def set_palette
        @palette = Palette.friendly_find(params[:palette_id])
      end
  end
end
