# Reverse discovery: paste a swatch, find out where it already lives.
class LookupsController < ApplicationController
  def show
    @query = params[:q].to_s
    return if @query.blank?

    @rgb = ColorSpace.parse(@query)
    return if @rgb.nil?

    @hex = ColorSpace.to_hex(@rgb[:r], @rgb[:g], @rgb[:b])
    @colors = Color.where(@rgb).order(:name)
    @palettes = Palette.containing_hex(@hex).order(:name)

    # "Not in the library" on its own sends you away to look somewhere else,
    # when the nearest thing on file is usually the answer you were after.
    # Only worth saying when nothing matched exactly — otherwise the nearest
    # colour is the one already named above it.
    @nearest = Color.nearest_to(@rgb) if @colors.empty?
  end
end
