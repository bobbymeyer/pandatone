module Api
  module V1
    class BaseController < ActionController::API
      include Sorting

      before_action :authenticate_client
      before_action :enforce_read_only

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

        # A read-only token may read the whole library and rewrite none of it.
        #
        # Decided on the HTTP verb rather than on a list of actions, because a
        # list is a thing to forget to add to: every route this API gains is
        # covered the moment it exists, and the one way to get it wrong would
        # be to write through a GET, which this API does not do.
        #
        # 403 and not 401. The credential is genuine and the client should not
        # go looking for a better one -- 401 means "authenticate", and it would
        # send a tool into a retry loop over something retrying cannot fix.
        def enforce_read_only
          return unless Current.user&.api_read_only?
          return if request.get? || request.head?

          render json: { error: "Read only" }, status: :forbidden
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
