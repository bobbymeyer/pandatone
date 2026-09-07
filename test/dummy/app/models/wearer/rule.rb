class Wearer::Rule < ApplicationRecord
  include Pandatone::Dresser::Rule

  validates :rank, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
