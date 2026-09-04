# The engine's JavaScript: two Stimulus controllers and the module that
# registers them with the host's Stimulus application. The layout imports
# that module, so a host has nothing to add to its own importmap or index.
pin "pandatone", to: "pandatone.js"
pin "pandatone/controllers/live_search_controller", to: "pandatone/controllers/live_search_controller.js"
pin "pandatone/controllers/swatch_preview_controller", to: "pandatone/controllers/swatch_preview_controller.js"
