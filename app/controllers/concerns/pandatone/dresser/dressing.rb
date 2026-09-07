# What a controller that dresses something needs from Pandatone: the
# catalogue, a palette out of it, and the drift sentence. The actions are the
# consumer's, because the routes and the redirects are; these are the three
# lines every one of them had in common.
module Pandatone
  module Dresser
    module Dressing
      extend ActiveSupport::Concern

      private
        # The catalogue, fetched afresh when the page asked for it with
        # `?refresh=1` — what "Refresh from Pandatone" sends.
        def catalog
          Catalog.forget! if params[:refresh].present?

          Catalog.current
        end

        # The palette a form named, or nil when the catalogue has no such
        # palette — which is the one thing to say about it.
        def palette_from_catalog(id)
          Catalog.current.find(id)
        end

        def drift_report(colorway)
          Drift.report(colorway)
        end
    end
  end
end
