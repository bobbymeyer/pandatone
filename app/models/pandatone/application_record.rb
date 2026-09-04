module Pandatone
  # Abstract, and only abstract: the primary class is the host's. The
  # engine's records share the host's connection and carry its table prefix.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
