module Pandatone
  module Api
    module V1
      # What the lookup screen answers, in one call: what this value is, whether
      # the library holds it, which palettes do, and — when it does not — the
      # closest thing on file.
      class LookupsController < BaseController
        def show
          answer = Pandatone.lookup(params[:q])
          return render_unreadable if answer.nil?

          render json: answer
        end

        private
          def render_unreadable
            render json: { errors: { q: [ "is not a hex, an RGB triple or a CMYK build" ] } },
              status: :unprocessable_content
          end
      end
    end
  end
end
