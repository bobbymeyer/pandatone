# Who else may make an account. One rank in this app: an admin decides, and
# everybody else is here to work on the library rather than on the people.
class InvitationsController < ApplicationController
  before_action :require_admin, only: %i[ create destroy ]

  def index
    @invitations = Invitation.order(:email_address)
    @invitation = Invitation.new
  end

  def create
    @invitation = Invitation.new(email_address: params[:email_address], invited_by: Current.user)

    if @invitation.save
      redirect_to invitations_path, notice: "#{@invitation.email_address} can now make an account."
    else
      @invitations = Invitation.order(:email_address)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    Invitation.find(params[:id]).destroy

    redirect_to invitations_path
  end

  private
    def require_admin
      redirect_to invitations_path, alert: "Only an admin can invite people." unless Current.user.admin?
    end
end
