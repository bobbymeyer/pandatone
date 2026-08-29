require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "gets an API token without being asked" do
    user = User.create!(email_address: "new@example.com", password: "a good password")

    assert user.api_token.present?
  end

  test "no two users share a token" do
    tokens = User.pluck(:api_token) + [ User.create!(email_address: "a@example.com", password: "a good password").api_token ]

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
    user = User.create!(email_address: "  MiXeD@Example.COM ", password: "a good password")

    assert_equal "mixed@example.com", user.email_address
  end

  # Enough that a guess is not a shortcut, and nothing beyond that. The worst
  # thing behind this door is somebody's colour swatches.
  test "a password is at least eight characters" do
    assert_not User.new(email_address: "a@example.com", password: "short").valid?
    assert User.new(email_address: "a@example.com", password: "long enough").valid?
  end

  test "the rule holds on the way in through sign up too" do
    User.destroy_all

    user = User.sign_up(email_address: "first@example.com", password: "short")

    assert_not user.persisted?
    assert_match(/too short/, user.errors.full_messages.to_sentence)
  end

  # The library belongs to whoever opened it. Everyone invited afterwards is
  # an ordinary account until someone says otherwise.
  test "an account is not an admin unless it is made one" do
    assert_not User.create!(email_address: "ordinary@example.com", password: "a good password").admin?
  end

  test "the first account to exist is the admin" do
    User.destroy_all

    first = User.sign_up(email_address: "first@example.com", password: "a good password")

    assert first.admin?
  end

  test "an account after the first is not" do
    Invitation.create!(email_address: "invited@example.com", invited_by: users(:keeper))

    invited = User.sign_up(email_address: "invited@example.com", password: "a good password")

    assert_not invited.admin?
  end

  # Signing up spends the invitation, so the list left on the invitations page
  # is exactly the people who have not arrived yet.
  test "signing up spends the invitation that allowed it" do
    Invitation.create!(email_address: "spent@example.com", invited_by: users(:keeper))

    assert_difference -> { Invitation.count }, -1 do
      User.sign_up(email_address: "spent@example.com", password: "a good password")
    end
  end

  test "refuses an address nobody invited, once an account exists" do
    user = User.sign_up(email_address: "stranger@example.com", password: "a good password")

    assert_not user.persisted?
    assert_match(/has not been invited/, user.errors.full_messages.to_sentence)
  end
end
