# What a color looks like, and every judgment the library makes about it.
#
# ColorSpace does the arithmetic — luma, hue, chroma, distance — and knows
# nothing about this app. This is the layer above: the four numbers that decide
# when two swatches are too alike to be worth having twice, where a color stops
# having a hue, and where a wheel gets cut to become a list. They are the
# library's policy, so they live together in the file named for it rather than
# scattered through a record that is otherwise about persistence.
module Pandatone
  module ColorGeometry
    extend ActiveSupport::Concern

    # Below this redmean distance two swatches are near enough that having both
    # is more likely a mistake than a decision: #FAFAF8 against #FFFFFF scores
    # 17, a red mistyped as #E01020 instead of #E30613 scores 28. Two grays
    # twenty steps apart score 60 and stay two swatches. The line is a judgment
    # about a library, not a perceptual constant, which is why it warns rather
    # than refuses.
    SIMILARITY_THRESHOLD = 32

    # Below this much chroma there is not enough hue to place on the spectrum,
    # so the color belongs on the black-to-white axis instead. It clears the
    # off-whites and the warm grays without catching a muted olive.
    NEUTRAL_CHROMA = 24

    # Half of 255: which end of the black-to-white axis a neutral belongs on.
    NEUTRAL_MIDPOINT = 127.5

    # A wheel has no beginning, so a linear list has to cut it somewhere, and
    # wherever the cut falls two neighboring colors end up at opposite ends.
    # Cutting at red would do it between #FF0010 and #FF0000 — putting a red
    # that leans a few degrees blue, like #E30613 at 356.5, after the violets.
    # The gap between magenta and red is the emptiest place to break, so the
    # cut goes there and every red stays with the reds.
    SPECTRUM_ORIGIN = 345

    included do
      # A bounding box, so a similarity search is an indexed range scan over a
      # handful of rows rather than a walk of the whole library. Every weight in
      # the distance is at least 2, and green's is exactly 4, so nothing inside
      # the threshold can fall outside this box.
      scope :near, ->(color) {
        reach = SIMILARITY_THRESHOLD / Math.sqrt(2)

        where(r: (color.r - reach)..(color.r + reach),
              g: (color.g - SIMILARITY_THRESHOLD / 2.0)..(color.g + SIMILARITY_THRESHOLD / 2.0),
              b: (color.b - reach)..(color.b + reach))
      }
    end

    class_methods do
      # The nearest swatch already on file that this one is close enough to be a
      # duplicate of, or nil. Exact matches are a validation, not a warning, so
      # by the time this is consulted the answer is always a genuinely distinct
      # color that merely looks the same.
      def similar_to(color)
        return nil unless [ color.r, color.g, color.b ].all?(Integer)

        scope = near(color)
        scope = scope.where.not(id: color.id) if color.persisted?

        nearest, distance = closest_in(scope, color.rgb)
        nearest if distance && distance <= SIMILARITY_THRESHOLD
      end

      # The closest color on file to a value, however far off it is. This is what
      # the lookup answers with when the library holds nothing matching exactly:
      # "we do not have that, but we have this". No threshold, because nearest
      # has to mean nearest, and no bounding box for the same reason — one query
      # over four integer columns reads the whole library.
      def nearest_to(rgb)
        closest_in(all, rgb).first
      end

      private
        def closest_in(scope, rgb)
          id, distance = scope.pluck(:id, :r, :g, :b)
            .map { |row| [ row.first, ColorSpace.distance(rgb, { r: row[1], g: row[2], b: row[3] }) ] }
            .min_by(&:last)

          id ? [ find(id), distance ] : [ nil, nil ]
        end
    end

    def luma
      ColorSpace.luma(r, g, b)
    end

    def hue
      ColorSpace.hue(r, g, b)
    end

    def chroma
      ColorSpace.chroma(r, g, b)
    end

    # A color with too little hue to place on the spectrum.
    def neutral?
      chroma < NEUTRAL_CHROMA
    end

    # Black, then ROYGBIV, then white: the neutrals split to the two ends of the
    # list by which half of the black-to-white axis they sit on, and everything
    # with a hue runs between them in spectral order.
    def spectrum_position
      return [ 0, luma ] if neutral? && luma < NEUTRAL_MIDPOINT
      return [ 2, luma ] if neutral?

      [ 1, (hue - SPECTRUM_ORIGIN) % 360 ]
    end

    def dark_position
      luma
    end

    def light_position
      -luma
    end
  end
end
