module Colors
  # Tags are edited in place on the colour page through a Turbo Frame, the
  # same as a palette's, and fall back to their own page without JavaScript.
  class TagsController < ApplicationController
    before_action :set_color

    def edit
    end

    def update
      if @color.update(params.require(:color).permit(:tag_list))
        redirect_to @color
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_color
        @color = Color.find(params[:color_id])
      end
  end
end
