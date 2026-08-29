# Regenerating is the whole of revocation: the token a tool holds stops
# working the moment the new one is written, and nothing else about the
# account changes.
class ApiTokensController < ApplicationController
  def update
    Current.user.regenerate_api_token

    redirect_to account_path, notice: "New token. Give it to anything that was using the old one."
  end
end
