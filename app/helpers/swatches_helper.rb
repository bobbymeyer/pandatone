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

  def channel_pairs(color)
    [
      [ "RGB", color.rgb.map { |channel, value| "#{channel.to_s.upcase} #{value}" }.join("  ") ],
      [ "CMYK", color.cmyk.map { |channel, value| "#{channel.to_s.upcase} #{value}" }.join("  ") ]
    ]
  end
end
