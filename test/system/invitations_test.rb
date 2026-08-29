require "application_system_test_case"

# The list of people who may make an account and have not yet.
class InvitationsTest < ApplicationSystemTestCase
  test "an admin reaches the invitations from the account page" do
    visit account_path

    click_on "Invitations"

    assert_text "Nobody is waiting on an invitation"
  end

  test "invites an address, which then appears on the list" do
    visit invitations_path

    fill_in "Email", with: "newcomer@example.com"
    click_on "Invite"

    assert_text "newcomer@example.com"
    assert Invitation.invited?("newcomer@example.com")
  end

  test "refuses an address that already has an account" do
    visit invitations_path

    fill_in "Email", with: users(:second).email_address
    click_on "Invite"

    assert_text "already has an account"
  end

  test "withdraws an invitation" do
    Invitation.create!(email_address: "regretted@example.com", invited_by: users(:keeper))

    visit invitations_path
    confirming { click_on "Withdraw" }

    assert_text "Nobody is waiting on an invitation"
    assert_not Invitation.invited?("regretted@example.com")
  end

  # Inviting people is the admin's job, and this app has exactly one rank.
  test "an ordinary account cannot reach the invitations at all" do
    users(:keeper).update!(admin: false)

    visit invitations_path

    assert_no_text "Invite"
    assert_text "Only an admin can invite people"
  end

  test "an ordinary account is not offered the link either" do
    users(:keeper).update!(admin: false)

    visit account_path

    assert_no_link "Invitations"
  end
end
