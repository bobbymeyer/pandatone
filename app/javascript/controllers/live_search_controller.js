import { Controller } from "@hotwired/stimulus"

// Submits a search form as you type, into the Turbo Frame it targets.
//
// The filtering itself stays on the server, in the same scope the button
// uses: there is one definition of what a search matches, not a Ruby one and
// a drifting JavaScript copy. The form sits outside its frame so only the
// results are replaced and the field keeps focus and cursor position.
//
// The button goes when this connects, because from that moment it is a second
// way to do the thing that has just been done. It is hidden here rather than
// left out of the markup for the browser that never runs this: without the
// controller the button is the only way to search, so it has to be in the
// page for the page to work.
export default class extends Controller {
  static targets = [ "submit" ]
  static values = { delay: { type: Number, default: 200 } }

  connect() {
    if (this.hasSubmitTarget) this.submitTarget.hidden = true
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
