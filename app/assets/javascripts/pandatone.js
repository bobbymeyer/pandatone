// Registers the engine's controllers with the host's Stimulus application.
// controllers/application is what stimulus-rails installs in every host; it
// is the one thing the engine assumes about the JavaScript around it.
import { application } from "controllers/application"
import LiveSearchController from "pandatone/controllers/live_search_controller"
import SwatchPreviewController from "pandatone/controllers/swatch_preview_controller"

application.register("live-search", LiveSearchController)
application.register("swatch-preview", SwatchPreviewController)
