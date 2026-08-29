require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "an address is stored the way it will be typed" do
    invitation = invite("  MiXeD@Example.COM ")

    assert_equal "mixed@example.com", invitation.email_address
  end

  # The address is the credential here, so the same address invited twice is
  # one invitation rather than two chances to sign up.
  test "one invitation per address" do
    invite("twice@example.com")

    assert_not invite("TWICE@example.com").valid?
  end

  test "refuses an address that already has an account" do
    invitation = Invitation.new(email_address: users(:keeper).email_address, invited_by: users(:keeper))

    assert_not invitation.valid?
    assert_match(/already has an account/, invitation.errors.full_messages.to_sentence)
  end

  test "refuses something that is not an address" do
    assert_not Invitation.new(email_address: "not-an-address", invited_by: users(:keeper)).valid?
  end

  test "refuses nothing at all" do
    assert_not Invitation.new(email_address: " ", invited_by: users(:keeper)).valid?
  end

  test "knows whether an address has been invited" do
    invite("expected@example.com")

    assert Invitation.invited?("EXPECTED@example.com")
    assert_not Invitation.invited?("stranger@example.com")
    assert_not Invitation.invited?(nil)
  end

  # Deleting the admin who invited someone should not quietly delete their
  # invitation, and it must not leave a row pointing at nobody either.
  test "belongs to the account that sent it" do
    assert_equal users(:keeper), invite("sent@example.com").invited_by
    assert_not Invitation.new(email_address: "nobody@example.com").valid?
  end

  private
    def invite(address)
      Invitation.create(email_address: address, invited_by: users(:keeper))
    end
end
