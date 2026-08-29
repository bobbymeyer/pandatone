class ColorsController < ApplicationController
  before_action :set_color, only: %i[ show edit update ]

  def index
    @colors = Color.name_matching(params[:q]).includes(:palettes)
    @colors = @colors.tagged(params[:tag]) if params[:tag].present?
    @colors = @colors.sorted(color_sort)
    @tags = Color.all_tags
    @total = Color.count
  end

  def show
    @palettes = @color.palettes.reorder(:name).includes(palette_colors: :color)
  end

  # Colours are first-class in the domain, so one can be brought into
  # existence without a palette to put it in — which the API has always
  # allowed and the interface did not.
  def new
    @color = Color.new
  end

  def create
    @color = Color.new(swatch_attributes)
    @similar = similar_swatch_for(@color)

    if @similar.nil? && @color.save
      redirect_to @color
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  # A colour is shared, so this edits it everywhere at once. That is the point
  # of one row per colour, and the form says so before you commit to it.
  def update
    @color.assign_attributes(swatch_attributes)
    @similar = similar_swatch_for(@color)

    if @similar.nil? && @color.save
      redirect_to @color
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    # An unrecognised sort is not worth an error page; it means name, which is
    # what the index did before there was anything to choose.
    def color_sort
      Color::SORTS.key?(params[:sort]) ? params[:sort] : "name"
    end
    helper_method :color_sort

    def set_color
      @color = Color.find(params[:id])
    end
end
