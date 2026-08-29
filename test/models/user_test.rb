require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "gets an API token without being asked" do
    user = User.create!(email_address: "new@example.com", password: "secret")

    assert user.api_token.present?
  end

  test "no two users share a token" do
    tokens = User.pluck(:api_token) + [ User.create!(email_address: "a@example.com", password: "x").api_token ]

    assert_equal tokens.uniq, tokens
  end

  test "regenerating replaces the token" do
    user = users(:keeper)

    assert_changes -> { user.reload.api_token } do
      user.regenerate_api_token
    end
  end

  # The token is the credential; the password is a separate one. Rotating
  # either has to leave the other alone, or revoking a leaked token would lock
  # you out of the interface and changing your password would break every
  # script at once.
  test "regenerating the token leaves the password alone" do
    user = users(:keeper)

    assert_no_changes -> { user.reload.password_digest } do
      user.regenerate_api_token
    end
  end

  test "an address is stored the way it will be typed" do
    user = User.create!(email_address: "  MiXeD@Example.COM ", password: "x")

    assert_equal "mixed@example.com", user.email_address
  end
end
