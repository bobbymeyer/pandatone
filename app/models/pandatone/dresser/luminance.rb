# OKLab's L, which is OKLCH's L: how light a colour looks, on a scale where
# the steps are perceptually even.
#
# Measured here rather than read off the record. Pandatone's own brightness
# figure is Rec. 601 luma — it does not linearize the gamma, and says so — and
# ranking a palette by a measure that is not perceptual puts the wrong colour
# in the ground. its-swiss's value scale is OKLCH lightness; a palette ranked
# by the same measure reads the way the library it is dressed in reads.
module Pandatone
  module Dresser
    module Luminance
      module_function

      # sRGB channels, 0–255, to L in 0–1.
      #
      # The gamma has to come off first — sRGB stores light bent so that the
      # low end gets more of the byte, and averaging the bent numbers is what
      # makes a mid gray look like it is halfway when it is at .60. The three
      # coefficient rows are the sRGB-to-LMS matrix, the cube roots are the
      # compression the eye applies to each cone, and the last row weighs them
      # back into one number.
      def of(red, green, blue)
        r, g, b = linearize(red), linearize(green), linearize(blue)

        long   = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        medium = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        short  = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        0.2104542553 * Math.cbrt(long) +
          0.7936177850 * Math.cbrt(medium) -
          0.0040720468 * Math.cbrt(short)
      end

      # Pandatone sends "#RRGGBB"; a hex typed by hand may not have the hash.
      def of_hex(hex)
        digits = hex.to_s.strip.delete_prefix("#")
        return nil unless digits.match?(/\A\h{6}\z/)

        of(*digits.scan(/\h{2}/).map { |pair| pair.to_i(16) })
      end

      # The inverse, for neutrals: the grey that measures a given lightness.
      #
      # Only neutrals, and that is what makes it a few lines rather than a
      # colour space conversion. A grey has its three channels equal, so its
      # three cone responses are equal too, and the whole of `of` collapses to
      # one cube root times the sum of the three weights — which is the same
      # 0.99999999347 that white comes out at. Inverting that is a cube and a
      # gamma.
      def grey(lightness)
        linear = (lightness.clamp(0.0, 1.0) / WHITE)**3
        channel = (delinearize(linear) * 255).round.clamp(0, 255)

        format("#%02X%02X%02X", *([ channel ] * 3))
      end

      # What `of` returns for white. Not one: the coefficients are published to
      # ten places and do not quite weigh back to unity through the cube roots.
      WHITE = 0.2104542553 + 0.7936177850 - 0.0040720468

      # The inverse of the transfer function sRGB stores its channels through.
      def linearize(channel)
        value = channel / 255.0

        value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      private_class_method :linearize

      def delinearize(value)
        value <= 0.0031308 ? value * 12.92 : (1.055 * value**(1 / 2.4)) - 0.055
      end
      private_class_method :delinearize
    end
  end
end
