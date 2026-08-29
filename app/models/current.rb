class Current < ActiveSupport::CurrentAttributes
  attribute :session
  # A browser arrives with a session and the user hangs off it; a script
  # arrives with a token and there is no session to hang anything off. Both
  # end up answering Current.user.
  attribute :api_user

  def user
    session&.user || api_user
  end

  def user=(user)
    self.api_user = user
  end
end
