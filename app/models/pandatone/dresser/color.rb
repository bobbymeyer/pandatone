# One of Pandatone's colours, as far as a consumer cares: something to put in
# a slot, and a measure of how light it looks so the slots can be ranked.
module Pandatone
  module Dresser
    class Color
      attr_reader :id, :name, :hex, :red, :green, :blue, :tags

      def self.from_json(json)
        json = json.to_h.deep_stringify_keys
        rgb = json["rgb"] || {}

        new(
          id: json["id"], name: json["name"], hex: json["hex"], tags: json["tags"] || [],
          red: rgb["r"], green: rgb["g"], blue: rgb["b"]
        )
      end

      def initialize(id:, name:, hex:, red: nil, green: nil, blue: nil, tags: [])
        @id, @name, @hex, @tags = id, name, hex, tags
        @red, @green, @blue = red, green, blue
      end

      # The three channels, whichever way this colour arrived. Pandatone sends
      # both spellings and they agree; a colour built from a hex alone — a
      # value scale's grey, or a snapshot of one — has only the hex.
      def channels
        return [ red, green, blue ] if red && green && blue

        hex.to_s.delete_prefix("#").scan(/\h{2}/).map { |pair| pair.to_i(16) }
      end

      # The wire format again, which is what a snapshot stores: identity and
      # value together, so a colour edited in Pandatone reads as drift.
      def to_h
        { "id" => id, "name" => name, "hex" => hex, "rgb" => { "r" => red, "g" => green, "b" => blue } }
      end

      # A value object, so two readings of the same colour are the same colour.
      # Identity and value together: two palettes can hold the same hex under
      # different ids, and for anything that names a position those are not
      # interchangeable.
      def ==(other)
        other.is_a?(Color) && id == other.id && hex == other.hex
      end
      alias eql? ==

      def hash
        [ id, hex ].hash
      end

      # The channels are preferred and the hex is the fallback for a payload
      # that carried only one.
      def luminance
        @luminance ||=
          if red && green && blue
            Luminance.of(red, green, blue)
          else
            Luminance.of_hex(hex)
          end
      end
    end
  end
end
