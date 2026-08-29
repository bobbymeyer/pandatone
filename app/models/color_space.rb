# Device RGB <-> CMYK conversion.
#
# Deliberately naive: the standard textbook formulas, no ICC profiles, no
# gamut mapping, no black generation or under-colour removal. The CMYK a
# colour reports is an approximation good enough to hand a printer as a
# starting point, and nothing more.
#
# The two directions are not symmetrical. RGB round-trips through CMYK
# losslessly, but many CMYK mixes collapse onto a single RGB triple, which
# is why Color records which space they were authored in and treats that
# space as the source of truth.
module ColorSpace
  module_function

  # rgb_to_cmyk(227, 6, 19) # => { c: 0.0, m: 97.4, y: 91.6, k: 11.0 }
  def rgb_to_cmyk(r, g, b)
    r, g, b = clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)
    red, green, blue = r / 255.0, g / 255.0, b / 255.0

    key = 1.0 - [ red, green, blue ].max
    return { c: 0.0, m: 0.0, y: 0.0, k: 100.0 } if key >= 1.0

    ink = 1.0 - key
    {
      c: percent((1.0 - red - key) / ink),
      m: percent((1.0 - green - key) / ink),
      y: percent((1.0 - blue - key) / ink),
      k: percent(key)
    }
  end

  # cmyk_to_rgb(0, 97.4, 91.6, 11.0) # => { r: 227, g: 6, b: 19 }
  def cmyk_to_rgb(c, m, y, k)
    key = 1.0 - clamp(k, 0, 100).to_f / 100.0
    {
      r: channel(c, key),
      g: channel(m, key),
      b: channel(y, key)
    }
  end

  # to_hex(227, 6, 19) # => "#E30613"
  def to_hex(r, g, b)
    format("#%02X%02X%02X", clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255))
  end

  # Accepts "#E30613", "e30613" and the "#FC0" shorthand. Returns nil rather
  # than raising: callers are usually handling user input or a query string.
  def parse_hex(hex)
    digits = hex.to_s.strip.delete_prefix("#")
    digits = digits.chars.map { |d| d * 2 }.join if digits.length == 3
    return nil unless digits.match?(/\A\h{6}\z/)

    {
      r: digits[0, 2].hex,
      g: digits[2, 2].hex,
      b: digits[4, 2].hex
    }
  end

  # Freeform input from a human: a hex, or an RGB triple in whatever
  # punctuation their tool produced. Six hex digits are read as hex, since
  # that is overwhelmingly what "123456" means in a colour field.
  def parse(input)
    parse_hex(input) || parse_triple(input)
  end

  # normalize_hex("fc0") # => "#FFCC00"
  def normalize_hex(hex)
    rgb = parse_hex(hex)
    to_hex(rgb[:r], rgb[:g], rgb[:b]) if rgb
  end

  # How different two colours look, on a 0..765 scale. This is "redmean": a
  # weighted RGB distance that tracks perception far better than the plain
  # Euclidean one — which reads a shift in green as no bigger than the same
  # shift in blue — while staying pure arithmetic. No profiles, no Lab, no
  # colour-science apparatus for a question that only needs an approximate
  # answer.
  def distance(a, b)
    mean = (a[:r] + b[:r]) / 2.0
    dr = a[:r] - b[:r]
    dg = a[:g] - b[:g]
    db = a[:b] - b[:b]

    Math.sqrt((2 + mean / 256) * dr**2 + 4 * dg**2 + (2 + (255 - mean) / 256) * db**2)
  end

  def parse_triple(input)
    channels = input.to_s.scan(/-?\d+/).map(&:to_i)
    return nil unless channels.length == 3 && channels.all? { |channel| (0..255).cover?(channel) }

    { r: channels[0], g: channels[1], b: channels[2] }
  end
  private_class_method :parse_triple

  def clamp(value, low, high)
    return low if value.nil?

    value.clamp(low, high)
  end
  private_class_method :clamp

  def percent(fraction)
    (fraction * 100.0).round(1)
  end
  private_class_method :percent

  def channel(ink, key)
    (255.0 * (1.0 - clamp(ink, 0, 100).to_f / 100.0) * key).round
  end
  private_class_method :channel
end
