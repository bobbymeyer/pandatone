# Substring search over a record's name, for the filter bars. Wildcards are
# escaped so a stray % in a search box does not quietly match everything.
module NameSearchable
  extend ActiveSupport::Concern

  included do
    scope :name_matching, ->(term) {
      term = term.to_s.strip
      next all if term.blank?

      where("LOWER(#{table_name}.name) LIKE ?", "%#{sanitize_sql_like(term.downcase)}%")
    }
  end
end
