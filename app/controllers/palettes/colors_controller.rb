module Palettes
  class ColorsController < ApplicationController
    before_action :set_palette

    def new
      @current = current_memberships
      @available = available_colors
    end

    # Two ways to fill a swatch: reach for a colour already in the library, or
    # describe a new one. Both end up appending to the same palette, so they
    # share one route and one transaction.
    def create
      spec = params[:color_id].present? ? { id: params[:color_id] } : swatch_spec

      if spec.nil?
        @palette.errors.add(:colors, "need a name and some values")
        return render_new
      end

      if PaletteComposition.new(@palette, attributes: {}, append: [ spec ]).save
        redirect_to @palette
      else
        render_new
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

      def current_memberships
        @palette.palette_colors.includes(:color)
      end

      # Offering a colour the palette already holds would only produce a
      # uniqueness error, so it is left out rather than shown and refused.
      def available_colors
        Color.where.not(id: @palette.color_ids).order(:name).name_matching(params[:q])
      end

      def render_new
        @current = current_memberships
        @available = available_colors
        render :new, status: :unprocessable_content
      end

      # Which panel the page opens on. A rejected submission comes back on the
      # panel it came from rather than resetting to the default.
      def swatch_source
        return "library" if params[:color_id].present?

        params[:source] == "library" ? "library" : "new"
      end
      helper_method :swatch_source
  end
end
