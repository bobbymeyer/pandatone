module Api
  module V1
    class BaseController < ActionController::API
      include Sorting

      before_action :authenticate_client

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private
        # A token and nothing else. The session cookie the browser carries is
        # deliberately not accepted here: honoring it would make every page on
        # the internet able to drive this API from a signed-in browser, which
        # is the whole of what CSRF is, and ActionController::API brings no
        # forgery protection to stand in the way.
        def authenticate_client
          Current.user = client_from_token

          render_unauthorized unless Current.user
        end

        # Rails reads both spellings of the header, so a client sending the
        # older `Token abc` is not turned away for a reason nobody could guess
        # from a 401.
        def client_from_token
          token, _options = ActionController::HttpAuthentication::Token.token_and_options(request)

          User.find_by(api_token: token) if token.present?
        end

        def render_unauthorized
          render json: { error: "Unauthorized" }, status: :unauthorized
        end

        def render_not_found
          render json: { error: "Not found" }, status: :not_found
        end

        def render_invalid(record)
          render json: { errors: record.errors.messages }, status: :unprocessable_content
        end
    end
  end
end
