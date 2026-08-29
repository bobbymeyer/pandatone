# Who is here and who has been asked. Admins only: it is the one screen about
# the people rather than about the library.
class PeopleController < ApplicationController
  before_action :require_admin

  def index
    @users = User.order(:email_address)
    @invitations = Invitation.order(:email_address)
    @invitation = Invitation.new
  end
end
