module Palettes
  # Tags are edited in place on the palette page through a Turbo Frame, and
  # fall back to their own page when JavaScript is not available.
  class TagsController < ApplicationController
    before_action :set_palette

    def edit
    end

    def update
      if @palette.update(params.require(:palette).permit(:tag_list))
        redirect_to @palette
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_palette
        @palette = Palette.friendly_find(params[:palette_id])
      end
  end
end
