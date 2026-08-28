module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private
        def render_not_found
          render json: { error: "Not found" }, status: :not_found
        end

        def render_invalid(record)
          render json: { errors: record.errors.messages }, status: :unprocessable_content
        end
    end
  end
end
