require "rails/engine"

# What the engine is built on. Required here rather than left to the host's
# Gemfile: a gem's dependencies are resolved by Bundler and loaded by nobody.
require "propshaft"
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"
require "its-swiss"

module Pandatone
  # A mountable engine: its own controllers, routes, views, migrations and
  # assets, under one namespace and one table prefix, so it can sit beside
  # other tools in a host without either knowing the other exists.
  #
  #   mount Pandatone::Engine, at: "/pandatone"
  #
  # Two things it takes from the host rather than bringing itself. The door:
  # every screen inherits from the host's ApplicationController and every API
  # endpoint from the host's API controller, and those decide who gets in
  # (see Pandatone.base_controller_class). The shell: the engine's layout
  # fills its slots and renders the host's layouts/application around them.
  class Engine < ::Rails::Engine
    isolate_namespace Pandatone

    # Adobe publishes no media type for its swatch format, so this is the one
    # the tools that read it send. Registering it is what lets a palette be
    # asked for as `.ase` on the same route that serves it as a page.
    initializer "pandatone.mime_types" do
      Mime::Type.register "application/x-adobe-ase", :ase unless Mime[:ase]
    end

    # The engine's migrations run with the host's rather than being copied
    # into it: a host that upgrades the gem gets the new migration without
    # running a generator, and a migration it never copied is one it cannot
    # leave stale.
    initializer "pandatone.migrations" do |app|
      unless app.root.to_s.start_with?(root.to_s)
        config.paths["db/migrate"].expanded.each do |path|
          app.config.paths["db/migrate"] << path
        end
      end
    end

    # Propshaft finds an engine's app/assets/stylesheets on its own; the
    # JavaScript is not in that default set.
    initializer "pandatone.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts") if app.config.respond_to?(:assets)
    end

    # Pinned from the engine rather than written into the host's importmap:
    # what the engine ships, the engine pins.
    initializer "pandatone.importmap", before: "importmap" do |app|
      next unless app.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/assets/javascripts")
    end
  end
end
