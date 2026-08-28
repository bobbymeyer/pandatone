import { Controller } from "@hotwired/stimulus"

// Live preview for the colour entry row.
//
// Which panel is visible is CSS's job, not this controller's: :has() on the
// checked radio handles it, so the right fields show even with scripting off.
// This only paints the preview.
//
// The conversion here is a deliberate duplicate of the server's ColorSpace.
// It exists to show you what you are typing; the value that gets stored is
// always the one the server computes.
export default class extends Controller {
  static targets = ["mode", "rgb", "cmyk", "hex", "picker", "preview", "readout"]
  static values = { mode: String }

  connect() {
    this.redraw()
  }

  redraw() {
    const rgb = this.currentRgb()
    const hex = rgb ? this.toHex(rgb) : ""

    this.previewTarget.style.backgroundColor = hex || "transparent"
    this.readoutTarget.textContent = hex
  }

  currentRgb() {
    switch (this.mode) {
      case "cmyk":   return this.fromCmyk()
      case "hex":    return this.parseHex(this.hasHexTarget ? this.hexTarget.value : "")
      case "picker": return this.parseHex(this.hasPickerTarget ? this.pickerTarget.value : "")
      default:       return this.fromRgb()
    }
  }

  get mode() {
    const checked = this.modeTargets.find((input) => input.checked)
    return checked ? checked.value : this.modeValue
  }

  fromRgb() {
    const [r, g, b] = this.rgbTargets.map((field) => this.clamp(field.value, 255))
    return [r, g, b].every((channel) => channel !== null) ? { r, g, b } : null
  }

  fromCmyk() {
    const [c, m, y, k] = this.cmykTargets.map((field) => this.clamp(field.value, 100))
    if ([c, m, y, k].some((channel) => channel === null)) return null

    const key = 1 - k / 100
    return {
      r: Math.round(255 * (1 - c / 100) * key),
      g: Math.round(255 * (1 - m / 100) * key),
      b: Math.round(255 * (1 - y / 100) * key)
    }
  }

  parseHex(value) {
    let digits = String(value).trim().replace(/^#/, "")
    if (digits.length === 3) digits = digits.split("").map((d) => d + d).join("")
    if (!/^[0-9a-f]{6}$/i.test(digits)) return null

    return {
      r: parseInt(digits.slice(0, 2), 16),
      g: parseInt(digits.slice(2, 4), 16),
      b: parseInt(digits.slice(4, 6), 16)
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
