import { Controller } from "@hotwired/stimulus"

// Submits a search form as you type, into the Turbo Frame it targets.
//
// The filtering itself stays on the server, in the same scope the Filter
// button uses: there is one definition of what a search matches, not a Ruby
// one and a drifting JavaScript copy. The form sits outside its frame so only
// the results are replaced and the field keeps focus and cursor position.
export default class extends Controller {
  static values = { delay: { type: Number, default: 200 } }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
