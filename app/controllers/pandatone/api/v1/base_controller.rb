module Pandatone
  module Api
    module V1
      # Every API endpoint. It inherits from the host's API controller, which
      # decides who may call it and answers 401 to everyone else; what the
      # engine adds is the shape of its own refusals.
      class BaseController < Pandatone.api_base_controller_class.constantize
        include Sorting

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
end
