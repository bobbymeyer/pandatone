class PalettesController < ApplicationController
  include Sorting

  before_action :set_palette, only: %i[ show edit update destroy ]

  def index
    @palettes = Palette.name_matching(params[:q]).includes(palette_colors: :color)
    @palettes = @palettes.tagged(params[:tag]) if params[:tag].present?
    @palettes = @palettes.sorted(sort_key)
    @tags = Palette.all_tags
    @total = Palette.count
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
