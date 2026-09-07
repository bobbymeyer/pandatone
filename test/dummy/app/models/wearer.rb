# The dummy host's consumer of the dresser. See db/migrate/*_create_wearers.
class Wearer < ApplicationRecord
  has_many :colorways, dependent: :destroy, inverse_of: :wearer
end
