module SwatchesHelper
  # The only colour in the interface. A swatch carries its own background, and
  # a transition name unique within the page so Turbo can morph it across a
  # navigation instead of crossfading it.
  def swatch_tag(hex, transition_name: nil, **options)
    styles = [ "background-color: #{hex}" ]
    styles << "view-transition-name: #{transition_name}" if transition_name.present?

    options[:class] = Array(options[:class]).unshift("swatch")
    tag.div(nil, **options, style: styles.join("; "))
  end

  # What the colour entry row should show. What was just submitted wins, so a
  # validation error does not wipe what you typed; then the colour being
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

  # Returns each space's channels as separate values rather than one string,
  # so a narrow card wraps between them instead of splitting "K 11.0" in half.
  def channel_pairs(color)
    [
      [ "RGB", color.rgb.map { |channel, value| "#{channel.to_s.upcase} #{value}" } ],
      [ "CMYK", color.cmyk.map { |channel, value| "#{channel.to_s.upcase} #{value}" } ]
    ]
  end
end
