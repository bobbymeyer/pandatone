# Whether the palette has moved since the snapshot was taken.
#
# Reported, never applied. A design that was finished should not change
# because someone else opened another tool — so a colorway goes on rendering
# from its snapshot, and what Pandatone has done since is a sentence.
module Pandatone
  module Dresser
    module Drift
      module_function

      def report(colorway)
        Catalog.forget!
        live = Catalog.current.find(colorway.palette_id)

        if live.nil?
          "Pandatone no longer has that palette. The snapshot is all there is of it now."
        elsif colorway.drifted_from?(live)
          "#{live.name} has moved in Pandatone since this snapshot. Nothing here has changed."
        else
          "#{live.name} is as it was when this snapshot was taken."
        end
      end
    end
  end
end
