# Reads the sort a request asked for. An unrecognised one is not worth an
# error page; it means name, which is what both indexes did before there was
# anything to choose.
module Sorting
  extend ActiveSupport::Concern

  included do
    # ActionController::API carries no view layer and so no helper_method.
    # The API reads the sort in the controller; only the HTML side needs it
    # in a template.
    helper_method :sort_key if respond_to?(:helper_method)
  end

  private
    def sort_key
      Sortable::SORTS.key?(params[:sort]) ? params[:sort] : "name"
    end
end
