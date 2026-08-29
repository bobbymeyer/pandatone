require "application_system_test_case"

# Who is here and who has been asked. One screen, admins only, because
# deciding who else is in the library is the only thing an admin does that
# everybody else does not.
class PeopleTest < ApplicationSystemTestCase
  test "an admin reaches it from the account page" do
    visit account_path

    click_on "People"

    assert_text users(:keeper).email_address
  end

  test "lists the accounts and who has yet to arrive" do
    Invitation.create!(email_address: "waiting@example.com", invited_by: users(:keeper))

    visit people_path

    assert_text users(:second).email_address
    assert_text "waiting@example.com"
  end

  test "invites an address" do
    visit people_path

    fill_in "Email", with: "newcomer@example.com"
    click_on "Invite"

    assert_text "newcomer@example.com"
    assert_not Invitation.for("newcomer@example.com").first.admin?
  end

  # An admin can hand over the thing that makes them one, which is the only
  # way to make a second without opening a console.
  test "invites an address as an admin" do
    visit people_path

    fill_in "Email", with: "deputy@example.com"
    check "As an admin"
    click_on "Invite"

    # Waits for the write before asking the database about it: a browser
    # returns from the click long before the request lands.
    assert_text "deputy@example.com · as admin"
    assert Invitation.for("deputy@example.com").first.admin?
  end

  test "an invitation sent as admin arrives as one" do
    Invitation.create!(email_address: "deputy@example.com", invited_by: users(:keeper), admin: true)

    assert User.sign_up(email_address: "deputy@example.com", password: "a good password").admin?
  end

  test "withdraws an invitation" do
    Invitation.create!(email_address: "regretted@example.com", invited_by: users(:keeper))

    visit people_path
    within("li", text: "regretted@example.com") { confirming { click_on "Withdraw" } }

    assert_no_text "regretted@example.com"
  end

  test "removes an account" do
    visit people_path
    within("li", text: users(:second).email_address) { confirming { click_on "Remove" } }

    assert_no_text users(:second).email_address
    assert_nil User.find_by(email_address: "second@example.com")
  end

  # Removing yourself is how a library ends up with nobody who can invite
  # anyone, so the button is not there to press.
  test "offers no way to remove yourself" do
    visit people_path

    within("li", text: users(:keeper).email_address) { assert_no_selector "input[value=Remove]" }
  end

  test "an ordinary account cannot reach it" do
    users(:keeper).update!(admin: false)

    visit people_path

    assert_current_path account_path
    assert_text "Only an admin"
  end

  test "and is not offered the link" do
    users(:keeper).update!(admin: false)

    visit account_path

    assert_no_link "People"
  end
end
