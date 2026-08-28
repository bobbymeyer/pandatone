class ColorsController < ApplicationController
  def show
    @color = Color.find(params[:id])
    @palettes = @color.palettes.reorder(:name)
  end
end
