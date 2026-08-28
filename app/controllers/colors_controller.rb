class ColorsController < ApplicationController
  before_action :set_color, only: %i[ show edit update ]

  def index
    @colors = Color.order(:name).name_matching(params[:q]).includes(:palettes)
    @colors = @colors.tagged(params[:tag]) if params[:tag].present?
    @tags = Color.all_tags
  end

  def show
    @palettes = @color.palettes.reorder(:name).includes(palette_colors: :color)
  end

  def edit
  end

  # A colour is shared, so this edits it everywhere at once. That is the point
  # of one row per colour, and the form says so before you commit to it.
  def update
    if @color.update(swatch_attributes)
      redirect_to @color
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_color
      @color = Color.find(params[:id])
    end
end
