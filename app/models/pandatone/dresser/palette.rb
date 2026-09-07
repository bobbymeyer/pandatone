# A palette as a consumer reads it: p colours, and the order they fall into
# when ranked by how light they look.
module Pandatone
  module Dresser
    class Palette
      attr_reader :id, :name, :tags, :colors

      def self.from_json(json)
        json = json.to_h.deep_stringify_keys

        new(
          id: json["id"], name: json["name"], tags: json["tags"] || [],
          colors: (json["colors"] || []).map { |color| Color.from_json(color) }
        )
      end

      def initialize(id:, name:, tags: [], colors: [])
        @id, @name, @tags, @colors = id, name, tags, colors
      end

      # p.
      def size
        colors.size
      end

      # Lightest first, because slot 0 is the ground and its-swiss numbers its
      # own ladder the same way round: --value-0 is paper at 98% lightness and
      # --value-5 is ink at 18%.
      #
      # Name and id break a tie. A colorway resolves against these ranks every
      # time it renders, and two colours of equal lightness that swapped places
      # between renders would move a slot for a reason nobody could see.
      def ranked
        @ranked ||= colors.sort_by { |color| [ -color.luminance, color.name.to_s, color.id.to_i ] }
      end

      # Auto-Value-Match needs a colour for every slot before it can rank them
      # against each other. Fewer colours than slots and there is nothing to
      # put in the last one.
      def serves?(slot_count)
        size >= slot_count
      end

      # Increment steps one colour per stripe and wraps, so the run only closes
      # on itself when the stripes are a whole number of times round the
      # palette. Anything else lands mid-cycle at the seam.
      def cycles_cleanly?(stripe_count)
        size.positive? && (stripe_count % size).zero?
      end
    end
  end
end
