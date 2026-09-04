module Pandatone
  module Api
    module V1
      # Every tag in use, which is what a client needs to offer the same
      # filtering the interface does. Tags are the whole discovery mechanism
      # here, so a consumer that cannot enumerate them cannot navigate.
      class TagsController < BaseController
        def index
          render json: Pandatone.tags
        end
      end
    end
  end
end
