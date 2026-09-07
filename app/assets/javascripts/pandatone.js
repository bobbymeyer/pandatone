// Registers the engine's controller with the host's Stimulus application.
// controllers/application is what stimulus-rails installs in every host; it
// is the one thing the engine assumes about the JavaScript around it. The
// live search is its-swiss's, and the host registers that one.
import { application } from "controllers/application"
import SwatchPreviewController from "pandatone/controllers/swatch_preview_controller"

application.register("swatch-preview", SwatchPreviewController)
