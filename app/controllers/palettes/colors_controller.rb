module Palettes
  class ColorsController < ApplicationController
    SOURCES = %w[ new library ].freeze

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
        @palette.errors.add(:base, "A swatch needs a name and some values")
        return render_new
      end

      # Only a colour being described from scratch can be a near-duplicate;
      # one picked out of the library is by definition already in it.
      if spec[:id].blank?
        @candidate = Color.new(spec)
        @similar = similar_swatch_for(@candidate)
        return render_new if @similar
      end

      if PaletteComposition.new(@palette, attributes: {}, append: [ spec ]).save
        redirect_to @palette
      else
        render_new
      end
    end

    # Swaps a swatch with its neighbour. Moving one swatch is a whole
    # interaction on its own, rather than something you compose by typing a
    # column of integers and then remembering to save them.
    def move
      membership = @palette.palette_colors.find_by!(color_id: params[:id])
      neighbour = neighbour_of(membership)

      if neighbour
        PaletteColor.transaction do
          position = membership.position
          membership.update!(position: neighbour.position)
          neighbour.update!(position: position)
        end
      end

      redirect_to @palette
    end

    # Removes the swatch from this palette only. The colour stays in the
    # library, because it may well sit in other palettes.
    #
    # Expressed as a replacement rather than a delete so that it goes through
    # the same check as every other write: taking a swatch out can land this
    # palette on the same set of colours as another one, and that is a
    # duplicate however it came about. It also closes the gap the removed
    # swatch left in the positions.
    def destroy
      membership = @palette.palette_colors.find_by!(color_id: params[:id])
      remaining = @palette.palette_colors.order(:position)
        .reject { |other| other.id == membership.id }
        .map { |other| { id: other.color_id } }

      if PaletteComposition.new(@palette, attributes: {}, colors: remaining).save
        redirect_to @palette
      else
        render "palettes/show", status: :unprocessable_content
      end
    end

    private
      def set_palette
        @palette = Palette.friendly_find(params[:palette_id])
      end

      def neighbour_of(membership)
        scope = @palette.palette_colors.where.not(id: membership.id)

        if params[:direction] == "up"
          scope.where(position: ...membership.position).order(:position).last
        else
          scope.where(position: (membership.position + 1)..).order(:position).first
        end
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

      # Which panel the page opens on. Reaching for a swatch the library
      # already holds is the default, because a library of near-identical
      # colours is the failure mode this app exists to avoid, and a default
      # that starts you typing a new one every time is how you get there.
      # Describing a new colour leads only when there is nothing to pick.
      #
      # A rejected submission comes back on the panel it came from rather than
      # resetting to the default.
      def swatch_source
        return "library" if params[:color_id].present?
        return "new" if params[:swatch].present?
        return params[:source] if SOURCES.include?(params[:source])

        @available.any? ? "library" : "new"
      end
      helper_method :swatch_source
  end
end
