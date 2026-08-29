# Making an account. There are exactly two ways to be allowed one: be the
# first person to arrive, or have been invited by someone who already is.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_closed, only: :new
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new(email_address: params[:email_address])
  end

  def create
    @user = User.sign_up(**registration_params)

    if @user.persisted?
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # Open to anyone while the library has nobody in it, and after that only
    # to an address on the list. Someone arriving uninvited is told the door
    # is shut rather than shown a form that will refuse them.
    def redirect_if_closed
      return if User.none? || Invitation.invited?(params[:email_address])

      redirect_to new_session_path, alert: "Sign ups are closed. Ask someone here to invite you."
    end

    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
        .to_h.symbolize_keys.slice(:email_address, :password, :password_confirmation)
    end
end
