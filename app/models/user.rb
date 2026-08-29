class User < ApplicationRecord
  has_secure_password
  # 24 characters of base58, generated on create. Regenerating it is the whole
  # of revocation: the old token stops working the moment the new one is
  # written, and nothing else about the account changes.
  has_secure_token :api_token
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
