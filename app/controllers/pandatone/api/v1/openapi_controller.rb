module Pandatone
  module Api
    module V1
      # The API's own description, in the format every client generator and
      # every automation tool reads. Open on purpose: it says what the doors
      # are, not what is behind them, and a tool has to read it before it can
      # ask for a key.
      class OpenapiController < ActionController::API
        def show
          render json: Pandatone.openapi
        end
      end
    end
  end
end
