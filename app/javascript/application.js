// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

const initializeTooltips = () => {
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((element) => {
    bootstrap.Tooltip.getOrCreateInstance(element)
  })
}

const disposeTooltips = () => {
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((element) => {
    bootstrap.Tooltip.getInstance(element)?.dispose()
  })
}

document.addEventListener("turbo:load", initializeTooltips)
document.addEventListener("turbo:frame-load", initializeTooltips)
document.addEventListener("turbo:before-cache", disposeTooltips)
