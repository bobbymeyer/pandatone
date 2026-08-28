class PalettesController < ApplicationController
  before_action :set_palette, only: %i[ show edit update destroy reorder ]

  def index
    @palettes = Palette.order(:name).name_matching(params[:q]).includes(palette_colors: :color)
    @palettes = @palettes.tagged(params[:tag]) if params[:tag].present?
    @tags = Palette.all_tags
  end

  def show
  end

  def new
    @palette = Palette.new
  end

  def edit
  end

  def create
    @palette = Palette.new

    if compose(@palette).save
      redirect_to @palette
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if compose(@palette).save
      redirect_to @palette
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @palette.destroy!
    redirect_to palettes_path
  end

  # Positions arrive as a value per swatch. Sorting by the submitted value and
  # renumbering from zero means a partly-filled or duplicated form still lands
  # on a sane order rather than being rejected.
  def reorder
    submitted = params.fetch(:positions, {})
    ordered = @palette.palette_colors.sort_by { |membership| [ submitted[membership.id.to_s].to_i, membership.position ] }

    PaletteColor.transaction do
      ordered.each_with_index { |membership, position| membership.update!(position: position) }
    end

    redirect_to @palette
  end

  private
    def set_palette
      @palette = Palette.friendly_find(params[:id])
    end

    def compose(palette)
      PaletteComposition.new(palette, attributes: palette_attributes, append: [ swatch_spec ].compact)
    end

    def palette_attributes
      params.require(:palette).permit(:name, :tag_list).to_h
    end
end
