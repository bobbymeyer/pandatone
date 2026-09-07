# The engine's JavaScript: one Stimulus controller and the module that
# registers it with the host's Stimulus application. The layout imports that
# module, so a host has nothing to add to its own importmap.
pin "pandatone", to: "pandatone.js"
pin "pandatone/controllers/swatch_preview_controller", to: "pandatone/controllers/swatch_preview_controller.js"
