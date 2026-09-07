# Something wearing a palette. The thing is composed in value and carries no
# colour; this is where colour is said, as a rule per slot over a snapshot of
# the palette, so it survives the thing being edited underneath it.
#
# For a consumer's record with `palette_id`, a `PaletteSnapshot` beside it in
# the same namespace, and a `slot_count` the consumer answers: how many slots
# the thing it dresses has.
module Pandatone
  module Dresser
    module Colorway
      extend ActiveSupport::Concern

      included do
        has_one :snapshot, class_name: "PaletteSnapshot", dependent: :destroy, inverse_of: :colorway

        validates :palette_id, presence: true
        validate :palette_serves_every_slot, on: :create
      end

      # Choosing a palette takes a snapshot of it. The two are one act: there
      # is no moment at which a colorway has a palette id and no colours.
      def palette=(palette)
        self.palette_id = palette.id

        build_snapshot(palette_name: palette.name, colors: palette.colors.map(&:to_h), taken_at: Time.current)
      end

      def palette_name
        snapshot&.palette_name
      end

      # Whether the thing has outgrown the palette.
      #
      # Derived and not stored, which is what lets a slot taken away revive a
      # colorway for nothing. A stored mark would have to be found and cleared
      # by whatever removed the slot; asked fresh, it cannot go stale.
      def invalidated?
        snapshot.nil? || snapshot.size < slot_count
      end

      def drifted_from?(palette)
        snapshot.present? && snapshot.drifted_from?(palette)
      end

      private
        def palette_serves_every_slot
          return if snapshot.nil? || snapshot.size >= slot_count

          errors.add(:palette, "has #{snapshot.size} colours for #{slot_count} slots")
        end
    end
  end
end
