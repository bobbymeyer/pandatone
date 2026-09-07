# The palette dresser: the consumer's side of Pandatone.
#
# Another tool composes in value — a pattern of ranked slots, a badge of
# ranked slots — and asks Pandatone what those values are wearing. This is
# how it asks, and everything it needs to hold the answer: a catalogue of
# palettes read in Pandatone's wire format, each colour measured for how light
# it looks so the palette can be ranked paper to ink; a snapshot of the
# palette taken at the moment it was chosen, so a design that was finished
# does not change because someone opened Pandatone; a rule per slot over that
# snapshot rather than a hex, so the design survives being edited underneath;
# and drift, asked for and reported, never applied.
#
# Stripeclub wrote it first and Badger copied it, and a pattern that appears
# in two consumers belongs to the thing they consume. A consumer includes the
# concerns in its own records, keeps its own tables, and renders the picker
# and the swatches with the partials and helpers here.
#
#   class Stripeclub::Colorway < ApplicationRecord
#     include Pandatone::Dresser::Colorway
#     belongs_to :pattern
#     def slot_count = pattern.slot_count
#   end
module Pandatone
  module Dresser
    # Every failure is its own class rather than a nil, because each would
    # otherwise arrive as "Pandatone has no palettes" — and a catalogue that is
    # empty because a token expired is worse than one that says so.
    Error = Class.new(StandardError)

    # The token was refused, or there was none to send.
    Unauthorized = Class.new(Error)

    # Asked for a palette that is not there.
    NotFound = Class.new(Error)

    # Nothing answered: refused, timed out, or no such host.
    Unreachable = Class.new(Error)

    # Where Pandatone is and what to show it at the door, when it is somewhere
    # else. Neither is required to boot: composing needs nothing from
    # Pandatone, only dressing does.
    mattr_accessor :url, default: ENV["PANDATONE_URL"].presence
    mattr_accessor :token, default: ENV["PANDATONE_TOKEN"].presence

    # Where palettes come from: anything that answers `call` with an array of
    # palettes in Pandatone's wire format — id, name, tags, and colors each
    # with id, name, hex and rgb.
    #
    # Unset, the answer follows the URL: a Pandatone somewhere else is asked
    # over HTTP with the token, and with no URL the Pandatone in this process
    # is asked through its public methods, which is what a host that mounts
    # both tools gets without writing a line. A consumer knows Pandatone by
    # its wire format and by nothing else, which is why the in-process answer
    # is handed over as the same hashes the API sends.
    mattr_accessor :source, default: -> { Dresser.default_source }

    class << self
      def default_source
        return Client.configured.palettes_json if url.present?

        Pandatone.palettes.filter_map { |summary| Pandatone.palette(summary[:id])&.deep_stringify_keys }
      end
    end
  end
end
