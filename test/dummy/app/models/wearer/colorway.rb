class Wearer::Colorway < ApplicationRecord
  include Pandatone::Dresser::Colorway

  belongs_to :wearer, inverse_of: :colorways
  has_many :rules, class_name: "Wearer::Rule", dependent: :destroy, inverse_of: :colorway

  delegate :slot_count, to: :wearer

  def rule_for(rank)
    rules.find { |rule| rule.rank == rank } || Wearer::Rule.new(colorway: self, rank: rank, kind: "auto_value_match")
  end

  def bind(rank, kind:, **settings)
    rules.find_or_initialize_by(rank: rank).tap { |rule| rule.update!(kind: kind, settings: settings.stringify_keys) }
  end

  # A hex per rank, or nothing while invalidated.
  def colors
    return [] if invalidated?

    (0...slot_count).map { |rank| color_for(rank)&.hex }
  end

  def color_for(rank)
    rule = rule_for(rank)
    rule.binds_to_rank? ? rule.color_at_rank(rank, of: slot_count) : rule.assigned_color
  end
end
