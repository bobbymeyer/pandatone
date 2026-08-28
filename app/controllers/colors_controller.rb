class ColorsController < ApplicationController
  def index
    @colors = Color.order(:name).name_matching(params[:q]).includes(:palettes)
    @colors = @colors.tagged(params[:tag]) if params[:tag].present?
    @tags = Color.all_tags
  end

  def show
    @color = Color.find(params[:id])
    @palettes = @color.palettes.reorder(:name)
  end
end
