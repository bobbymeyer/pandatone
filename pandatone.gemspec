require_relative "lib/pandatone/version"

Gem::Specification.new do |spec|
  spec.name        = "pandatone"
  spec.version     = Pandatone::VERSION
  spec.authors     = [ "Bobby Meyer" ]
  spec.email       = [ "bobby@bobbymeyer.com" ]
  spec.homepage    = "https://github.com/bobbymeyer/pandatone"
  spec.summary     = "A palette library, as a Rails engine."
  spec.description = <<~TEXT.strip
    Named, tagged colors and the palettes that hold them, with a versioned JSON
    API and a Ruby interface, so other tools can ask two questions: give me the
    colors of the palette tagged active, and which palettes contain #E30613.
  TEXT
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  # Not published to RubyGems: a host takes the gem from a tag. If it ever
  # is, MFA should be required for the push.
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].select { |path| File.file?(path) }
  end

  # Bounded a major up rather than left open: the engine touches routing,
  # Active Record and the asset paths, all stable within a major and none of
  # them promised across one.
  spec.add_dependency "rails", ">= 8.0", "< 9"
  # The typographic style every screen is set in. Declared here rather than
  # taken from the host on faith, so the engine renders the same anywhere it
  # is mounted. Bundler resolves the host's copy and this one to a single gem.
  spec.add_dependency "its-swiss", "~> 0.7"
  spec.add_dependency "propshaft", ">= 1.0", "< 3"
  spec.add_dependency "importmap-rails", ">= 2.0", "< 4"
  spec.add_dependency "turbo-rails", ">= 2.0", "< 3"
  spec.add_dependency "stimulus-rails", ">= 1.3", "< 2"
end
