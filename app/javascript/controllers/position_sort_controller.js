import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]
  static values = {
    section: String,
    url: String
  }

  connect() {
    this.draggedRow = null
    this.isSaving = false
    this.rowTargets.forEach((row) => this.bindRowEvents(row))
  }

  bindRowEvents(row) {
    row.addEventListener("dragstart", (event) => this.dragStart(event))
    row.addEventListener("dragover", (event) => this.dragOver(event))
    row.addEventListener("drop", (event) => this.drop(event))
    row.addEventListener("dragend", () => this.dragEnd())
  }

  dragStart(event) {
    if (this.isSaving) {
      event.preventDefault()
      return
    }

    this.draggedRow = event.currentTarget
    this.draggedRow.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedRow.dataset.positionId)
  }

  dragOver(event) {
    event.preventDefault()

    const targetRow = event.currentTarget
    if (!this.draggedRow || this.draggedRow === targetRow) return

    const bounds = targetRow.getBoundingClientRect()
    const insertBefore = event.clientY < bounds.top + (bounds.height / 2)

    if (insertBefore) {
      targetRow.parentNode.insertBefore(this.draggedRow, targetRow)
    } else {
      targetRow.parentNode.insertBefore(this.draggedRow, targetRow.nextSibling)
    }
  }

  drop(event) {
    event.preventDefault()
    if (!this.draggedRow) return

    this.persistOrder()
  }

  dragEnd() {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("is-dragging")
    }

    this.draggedRow = null
  }

  async persistOrder() {
    this.isSaving = true
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const orderedIds = this.rowTargets.map((row) => row.dataset.positionId)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          position: {
            section: this.sectionValue,
            ordered_ids: orderedIds
          }
        })
      })

      if (!response.ok) {
        window.location.reload()
      }
    } finally {
      this.isSaving = false
    }
  }
}
