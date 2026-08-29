# Removing an account, which takes its sessions and any invitations it sent
# with it. An admin cannot remove themselves: that is how a library ends up
# with nobody who can invite anybody.
class UsersController < ApplicationController
  before_action :require_admin

  def destroy
    user = User.find(params[:id])

    if user == Current.user
      redirect_to people_path, alert: "You cannot remove your own account."
    else
      user.destroy
      redirect_to people_path
    end
  end
end
