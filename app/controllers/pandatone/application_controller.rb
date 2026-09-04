module Pandatone
  # Every screen in the engine. It inherits from the host's controller so the
  # host's door — whatever authentication it runs before an action — is the
  # engine's too, and the engine never has to know what a user is. What is
  # added here is only what every screen of a palette library needs.
  class ApplicationController < Pandatone.base_controller_class.constantize
    include SwatchParameters

    helper SwatchesHelper
  end
end
