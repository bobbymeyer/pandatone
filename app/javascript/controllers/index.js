// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// its-swiss pins its clipboard controller from the engine rather than writing
// a pin this app would have to keep in step. It is outside controllers/, so
// it is registered by hand: eagerLoadControllersFrom only reaches what is
// pinned under that name.
import ItsSwissClipboardController from "its_swiss/clipboard_controller"
application.register("its-swiss-clipboard", ItsSwissClipboardController)
