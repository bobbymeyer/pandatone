class ApplicationController < ActionController::Base
  include Authentication
  include SwatchParameters

  # With no account in existence there is nobody to be, so nothing asks you to
  # be anybody: signing in and resetting a password both lead to the one thing
  # that can be done instead. require_authentication says the same for every
  # page behind the door; this covers the three that are in front of it.
  before_action :redirect_to_sign_up_while_the_library_is_empty

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # One rank, and it decides exactly one thing: who else is here.
    def require_admin
      redirect_to account_path, alert: "Only an admin can decide who else is here." unless Current.user&.admin?
    end

    def redirect_to_sign_up_while_the_library_is_empty
      # A session means an account exists, so the question is already answered
      # and not worth a query. Signing up is where this would send you anyway.
      return if Current.session || controller_name == "registrations"

      redirect_to new_registration_path if User.none?
    end
end
