class User < ApplicationRecord
  has_secure_password
  # 24 characters of base58, generated on create. Regenerating it is the whole
  # of revocation: the old token stops working the moment the new one is
  # written, and nothing else about the account changes.
  has_secure_token :api_token
  has_many :sessions, dependent: :destroy
  # Nobody stands behind an invitation whose sender is gone, so it goes too.
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id,
    dependent: :destroy, inverse_of: :invited_by

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Making an account, which is a different act from creating a User row: it
  # decides whether this address is allowed one at all.
  #
  # The first account opens the library and is the admin. Every one after it
  # needs an invitation, and spends it on the way in — both in one transaction,
  # so a failure to save cannot burn someone's only way to sign up.
  def self.sign_up(email_address:, password:, password_confirmation: nil)
    transaction do
      invitation = Invitation.for(email_address).first
      first_account = none?

      user = new(email_address: email_address, password: password,
        password_confirmation: password_confirmation, admin: first_account)

      unless first_account || invitation
        user.errors.add(:email_address, "has not been invited")
        return user
      end

      invitation&.destroy! if user.save

      user
    end
  end
end
