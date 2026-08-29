# An address that is allowed to make an account.
#
# Sign-ups are closed by default: the first account to exist opens the library
# and every one after it arrives through here. Signing up spends the row, so
# what is left is exactly the list of people who have not arrived yet.
class Invitation < ApplicationRecord
  belongs_to :invited_by, class_name: "User"

  normalizes :email_address, with: ->(address) { address.to_s.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validate :must_not_already_have_an_account

  scope :for, ->(address) { where(email_address: address.to_s.strip.downcase) }

  def self.invited?(address)
    address.present? && self.for(address).exists?
  end

  private
    def must_not_already_have_an_account
      return if email_address.blank?

      errors.add(:email_address, "already has an account") if
        User.exists?(email_address: email_address)
    end
end
