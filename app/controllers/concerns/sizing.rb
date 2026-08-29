# Reads the card size a request asked for. Like the sort beside it, an
# unrecognized one is not worth an error page: it means small, which is what
# an index of a library is for — seeing how much of it you can at once.
module Sizing
  extend ActiveSupport::Concern

  # Small first, and small by default: the point of an index is the whole
  # shelf, and large is for looking closely at part of it.
  SIZES = { "small" => "Small", "large" => "Large" }.freeze

  included do
    helper_method :size_key if respond_to?(:helper_method)
  end

  private
    def size_key
      SIZES.key?(params[:size]) ? params[:size] : "small"
    end
end
