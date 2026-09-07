# The dresser's markup: a palette on the ladder, a slot's swatch, and a rule
# in words. Included in every view of the host, because the consumer's views
# are the ones that use it.
module Pandatone
  module DresserHelper
    # A palette as the picker shows it: its colours in luminance rank, drawn
    # as the greys of their own lightness.
    #
    # Not in their own colours, and that is the call rather than a shortcut.
    # The preview is the one place colour belongs, and what a palette is *for*
    # here is its distribution of value — which is the thing you cannot see
    # when six hues are shouting. Choose on the ladder, then look at the
    # preview.
    def palette_strip(palette)
      tag.ol(class: "palette-strip") do
        safe_join(palette.ranked.map { |color| palette_swatch(color) })
      end
    end

    def palette_swatch(color)
      tag.li do
        safe_join([
          tag.span(class: "palette-swatch", style: "background: #{Dresser::Luminance.grey(color.luminance)}"),
          tag.span(color.name, class: "palette-swatch__name")
        ])
      end
    end

    # A slot's swatch: the colour it resolves to, or a hatch when it is bound
    # to a rule rather than its rank, because its rank has stopped deciding
    # anything and a swatch that went on showing one would be showing
    # something the colorway no longer reads.
    #
    # The hatch is never the only thing saying so — every place this is used
    # names the rule in words beside it — because a pattern in a small square
    # is exactly the kind of signal some readers do not get.
    def slot_swatch(hex, ruled: false)
      return tag.span(class: "slot-swatch slot-swatch--ruled") if ruled

      tag.span(class: "slot-swatch", style: "background: #{hex}")
    end

    # A rule in words. The two kinds every consumer has are said here; a
    # consumer with more passes a block that says its own.
    def rule_in_words(rule)
      case rule.kind
      when "auto_value_match" then "By rank"
      when "assigned_slot" then "Palette colour #{rule.slot}"
      else block_given? ? yield(rule) : rule.kind.humanize
      end
    end
  end
end
