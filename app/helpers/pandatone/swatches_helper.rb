module Pandatone
  module SwatchesHelper
    # The only color in the interface. A swatch carries its own background, and
    # a transition name unique within the page so Turbo can morph it across a
    # navigation instead of crossfading it.
    def swatch_tag(hex, transition_name: nil, **options)
      styles = [ "background-color: #{hex}" ]
      styles << "view-transition-name: #{transition_name}" if transition_name.present?

      options[:class] = Array(options[:class]).unshift("swatch")
      tag.div(nil, **options, style: styles.join("; "))
    end

    # What the color entry row should show. What was just submitted wins, so a
    # validation error does not wipe what you typed; then the color being
    # edited; then nothing, for a fresh row.
    def swatch_field_value(key, color)
      return submitted_swatch[key] if params[:swatch].present?
      return nil if color.nil?

      case key.to_sym
      when :name         then color.name
      when :tags         then color.tag_list
      when :hex, :picker then color.hex
      else                    color.public_send(key)
      end
    end

    # "4 palettes in the library" when nothing is filtered, "1 of 4 palettes"
    # when something is. Saying "1 palette in the library" over a filtered list
    # was a plain falsehood about the library.
    def result_count(shown, total, noun)
      return "#{pluralize(total, noun)} in the library" if shown == total

      "#{shown} of #{pluralize(total, noun)}"
    end

    # Tags on a card look exactly like the tags in the filter bar because they
    # are the same thing: the library's whole discovery mechanism. So they
    # behave like it too, rather than being inert text wearing a control's
    # clothes.
    def tag_links(tags, &url)
      safe_join(tags.map { |tag| link_to(tag, url.call(tag), class: "tag") }, " · ")
    end

    # A hex on screen exists to be pasted somewhere else, so it is a button
    # that copies itself — which is its-swiss's copy_button, because nothing
    # about copying a value is about color. What is this app's is that a hex
    # is one, and that it reads as a hex while it does it.
    def hex_tag(hex, **options)
      options[:class] = Array(options[:class]).unshift("hex")

      copy_button(hex, **options)
    end

    # Says what deleting will actually do. A color no palette holds is a small
    # act; one that four palettes hold is four palettes changing, and the
    # confirmation is the last place to say so.
    def delete_color_warning(color, palettes)
      return "Delete #{color.name}? No palette holds it." if palettes.empty?

      "#{color.name} is in #{palettes.map(&:name).to_sentence}. " \
        "Delete it and take it out of #{palettes.one? ? "that palette" : "those palettes"}?"
    end

    # Each space with its channels as name-and-value pairs: separate values so a
    # narrow card wraps between them instead of splitting "K 11.0" in half, and
    # the name kept apart from the number so the two can be told apart by weight
    # rather than by counting characters.
    def channel_pairs(color)
      [
        [ "RGB", color.rgb.map { |channel, value| [ channel.to_s.upcase, value ] } ],
        [ "CMYK", color.cmyk.map { |channel, value| [ channel.to_s.upcase, value ] } ]
      ]
    end
  end
end
