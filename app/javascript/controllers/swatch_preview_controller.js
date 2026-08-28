import { Controller } from "@hotwired/stimulus"

// Live preview for the colour entry row, and the RGB/CMYK toggle.
//
// The conversion here is a deliberate duplicate of the server's ColorSpace:
// it exists only to paint a preview while you type. The value that gets
// stored is always the one the server computes.
export default class extends Controller {
  static targets = ["space", "rgb", "cmyk", "rgbFields", "cmykFields", "preview", "hex"]
  static values = { source: String }

  connect() {
    this.spaceChanged()
  }

  spaceChanged() {
    const cmyk = this.source === "cmyk"
    this.rgbFieldsTarget.hidden = cmyk
    this.cmykFieldsTarget.hidden = !cmyk
    this.redraw()
  }

  redraw() {
    const rgb = this.source === "cmyk" ? this.cmykToRgb() : this.rgbFromFields()
    const hex = rgb ? this.toHex(rgb) : ""

    this.previewTarget.style.backgroundColor = hex || "transparent"
    this.hexTarget.textContent = hex
  }

  get source() {
    const checked = this.spaceTargets.find((input) => input.checked)
    return checked ? checked.value : this.sourceValue
  }

  rgbFromFields() {
    const [r, g, b] = this.rgbTargets.map((field) => this.clamp(field.value, 255))
    return [r, g, b].every((channel) => channel !== null) ? { r, g, b } : null
  }

  cmykToRgb() {
    const [c, m, y, k] = this.cmykTargets.map((field) => this.clamp(field.value, 100))
    if ([c, m, y, k].some((channel) => channel === null)) return null

    const key = 1 - k / 100
    return {
      r: Math.round(255 * (1 - c / 100) * key),
      g: Math.round(255 * (1 - m / 100) * key),
      b: Math.round(255 * (1 - y / 100) * key)
    }
  }

  clamp(value, max) {
    if (value === "") return null

    const number = Number(value)
    return Number.isNaN(number) ? null : Math.min(Math.max(number, 0), max)
  }

  toHex({ r, g, b }) {
    return "#" + [r, g, b].map((channel) => Math.round(channel).toString(16).padStart(2, "0").toUpperCase()).join("")
  }
}
