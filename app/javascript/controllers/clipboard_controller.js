import { Controller } from "@hotwired/stimulus"

// Copies a value to the clipboard and says so, briefly.
//
// The element is a real button wrapping the text it copies, so the value is
// still readable and selectable with JavaScript off or the clipboard refused
// — taking a hex by hand is what everyone does today, and this only has to
// be faster than that, never the only way.
export default class extends Controller {
  static values = { text: String, confirmFor: { type: Number, default: 1200 } }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      // A denied permission or an insecure origin. Nothing is broken: the
      // value is on screen, so say nothing rather than raise an alarm.
      return
    }

    this.element.dataset.copied = "true"
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => delete this.element.dataset.copied, this.confirmForValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
