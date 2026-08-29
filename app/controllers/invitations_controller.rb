class InvitationsController < ApplicationController
  before_action :require_admin

  def create
    invitation = Invitation.new(invitation_params.merge(invited_by: Current.user))

    if invitation.save
      redirect_to people_path, notice: "#{invitation.email_address} can now make an account."
    else
      redirect_to people_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    Invitation.find(params[:id]).destroy

    redirect_to people_path
  end

  private
    def invitation_params
      params.permit(:email_address, :admin).to_h.symbolize_keys.slice(:email_address, :admin)
    end
end
