class PalettesController < ApplicationController
  include Sorting
  include Sizing
  include PaletteExports

  before_action :set_palette, only: %i[ show edit update destroy ]
  before_action :set_source, only: %i[ new create ]

  def index
    @palettes = Palette.name_matching(params[:q]).includes(palette_colors: :color)
    @palettes = @palettes.tagged(params[:tag]) if params[:tag].present?
    @palettes = @palettes.sorted(sort_key)
    @tags = Palette.all_tags
    @total = Palette.count
  end

  def show
    respond_to do |format|
      format.html
      format.ase { send_palette(@palette, :ase) }
      format.css { send_palette(@palette, :css) }
    end
  end

  # A palette can be started from another one. The swatches are carried into
  # the form rather than saved, because a saved clone is the duplicate the
  # uniqueness rule forbids — the fork would have to be created and then
  # immediately changed, and the created state is the one that cannot exist.
  def new
    @palette = Palette.new
    @palette.name = "#{@source.name} copy" if @source
  end

  def edit
  end

  def create
    @palette = Palette.new
    composition = PaletteComposition.new(@palette, attributes: palette_attributes,
      colors: carried_specs + [ swatch_spec ].compact)

    if composition.save
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

    def set_source
      @source = Palette.friendly_find(params[:from]) if params[:from].present?
    end

    # The blank the form always submits keeps "every box unticked" distinct
    # from "no boxes on the page", which are otherwise the same empty param.
    def carried_specs
      carried_color_ids.map { |id| { id: id } }
    end

    def carried_color_ids
      return @source&.color_ids.to_a if params[:carried].nil?

      Array(params[:carried]).reject(&:blank?).map(&:to_i)
    end
    helper_method :carried_color_ids

    def compose(palette)
      PaletteComposition.new(palette, attributes: palette_attributes, append: [ swatch_spec ].compact)
    end

    def palette_attributes
      params.require(:palette).permit(:name, :tag_list).to_h
    end
end
