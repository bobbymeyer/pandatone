module Pandatone
  module ApplicationHelper
    # Which destination in the nav you are at. current_page? answers for one
    # address, and a section is more than one: /palettes/12 and
    # /palettes/12/edit are both still Palettes, and the root is the palette
    # index under another name. Everything a controller and its nested ones
    # serve belongs to the section they are named for.
    def in_section?(section)
      path = controller_path.delete_prefix("pandatone/")

      path == section || path.start_with?("#{section}/")
    end
  end
end
