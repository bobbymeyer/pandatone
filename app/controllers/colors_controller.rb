class ColorsController < ApplicationController
  include Sorting

  before_action :set_color, only: %i[ show edit update destroy ]

  def index
    @colors = Color.name_matching(params[:q]).includes(:palettes)
    @colors = @colors.tagged(params[:tag]) if params[:tag].present?
    @colors = @colors.sorted(sort_key)
    @tags = Color.all_tags
    @total = Color.count
  end

  def show
    @palettes = holding_palettes
  end

  # Colors are first-class in the domain, so one can be brought into
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

  # A color is shared, so this edits it everywhere at once. That is the point
  # of one row per color, and the form says so before you commit to it.
  def update
    @color.assign_attributes(swatch_attributes)
    @similar = similar_swatch_for(@color)

    if @similar.nil? && @color.save
      redirect_to @color
    else
      render :edit, status: :unprocessable_content
    end
  end

  # A color is shared, so this is the one deletion in the app that can rewrite
  # records the button does not name. ColorRemoval refuses until the request
  # says so in as many words.
  def destroy
    if ColorRemoval.new(@color, from_palettes: params[:from_palettes].present?).destroy
      redirect_to colors_path
    else
      @palettes = holding_palettes
      render :show, status: :unprocessable_content
    end
  end

  private
    def holding_palettes
      @color.palettes.reorder(:name).includes(palette_colors: :color)
    end

    def set_color
      @color = Color.find(params[:id])
    end
end
