# Reads the card size a request asked for. Like the sort beside it, an
# unrecognized one is not worth an error page: it means large, which is what
# both indexes were before there was anything to choose.
module Sizing
  extend ActiveSupport::Concern

  # Small first, because it is the choice being offered — large is what you
  # already have.
  SIZES = { "small" => "Small", "large" => "Large" }.freeze

  included do
    helper_method :size_key if respond_to?(:helper_method)
  end

  private
    def size_key
      SIZES.key?(params[:size]) ? params[:size] : "large"
    end
end
