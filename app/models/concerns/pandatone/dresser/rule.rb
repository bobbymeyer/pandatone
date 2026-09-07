# What one slot of a colorway resolves to.
#
# A rule and not an assignment, which is the difference the whole design turns
# on: a colorway that stored hexes would be wrong the moment the structure
# under it changed, and a rule is still right.
#
# Two kinds every consumer has. Auto-Value-Match reads the slot's rank on the
# thing's own ladder against the palette's lightness ranks, both ends kept
# when the palette has more colours than there are slots. Assigned Slot names
# a position in the palette's own order — which is why a palette reordered in
# Pandatone counts as drift even when every colour in it is unchanged. A
# consumer with more kinds says so with `kinds` and `kind_predicates`.
#
# For a consumer's record with `kind`, `settings` (json) and a colorway.
module Pandatone
  module Dresser
    module Rule
      extend ActiveSupport::Concern

      KINDS = %w[ auto_value_match assigned_slot ].freeze

      included do
        belongs_to :colorway

        # A rule that has said nothing still has an empty settings hash rather
        # than no hash. The default rule is built and never saved, so nothing
        # else would ever give it one.
        attribute :settings, default: -> { {} }
        store_accessor :settings, :slot

        # Predicates written out rather than taken from `enum`: an enum over
        # these names generates `increment!`, and Active Record already has
        # one.
        kind_predicates(*KINDS)

        validates :kind, inclusion: { in: ->(rule) { rule.class.kinds } }
        validate :settings_fit_the_palette
      end

      class_methods do
        def kinds
          KINDS
        end

        def kind_predicates(*names)
          names.each { |name| define_method("#{name}?") { kind == name } }
        end
      end

      # Whether the slot is still doing value work. Auto-Value-Match resolves
      # through the luminance rank, so the slot's place in the ladder decides
      # its colour; every other kind resolves through a position in the
      # palette, and the rank stops mattering. The editor marks the difference.
      def binds_to_rank?
        auto_value_match?
      end

      # Auto-Value-Match, and the only place a rank is read: the colour at
      # this rank of `of` ranks. Both ends of the palette are kept when it has
      # more colours than there are ranks.
      def color_at_rank(rank, of:)
        return nil if size.zero?

        index = of <= 1 ? 0 : (rank * (size - 1)).fdiv(of - 1).round
        palette.ranked[index]
      end

      # Assigned Slot: palette[slot], moved along by `offset` colours.
      def assigned_color(offset = 0)
        at(slot.to_i + offset)
      end

      private
        def palette
          colorway.snapshot.palette
        end

        def size
          colorway.snapshot.size
        end

        def at(index)
          palette.colors[index % size]
        end

        def settings_fit_the_palette
          return if colorway.nil? || colorway.snapshot.nil?

          check_index(:slot, slot) if assigned_slot?
        end

        # i < p, and not negative. A rule naming a colour the palette does not
        # have is the same mistake as a colorway whose palette cannot fill
        # every slot, caught in the same place.
        def check_index(attribute, index)
          return if index.is_a?(Integer) && index.between?(0, size - 1)

          errors.add(attribute, "has to name one of the palette's #{size} colours")
        end
    end
  end
end
