import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["alert", "cell", "message"]

  connect() {
    this.copyShift = null
    this.draggedShift = null
    this.optionPointerDrag = null
    this.optionKeyPressed = false
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.cancelCopy()
    }
    this.keyDownHandler = (event) => {
      if (event.key === "Alt") this.optionKeyPressed = true
    }
    this.keyUpHandler = (event) => {
      if (event.key === "Alt") this.optionKeyPressed = false
    }
    this.blurHandler = () => {
      this.optionKeyPressed = false
    }
    this.pointerMoveHandler = (event) => this.optionPointerMove(event)
    this.pointerUpHandler = (event) => this.optionPointerUp(event)
    document.addEventListener("keydown", this.escapeHandler)
    document.addEventListener("keydown", this.keyDownHandler)
    document.addEventListener("keyup", this.keyUpHandler)
    window.addEventListener("blur", this.blurHandler)
    this.restoreViewport()
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
    document.removeEventListener("keydown", this.keyDownHandler)
    document.removeEventListener("keyup", this.keyUpHandler)
    window.removeEventListener("blur", this.blurHandler)
    this.removeOptionPointerListeners()
  }

  optionPointerDown(event) {
    if (!event.altKey || event.button !== 0 || event.target.closest("button, form")) return

    event.preventDefault()
    const shiftElement = event.currentTarget
    this.draggedShift = this.shiftData(shiftElement)
    this.draggedShift.dragAction = "copy"
    this.optionPointerDrag = {
      shiftElement,
      ghost: null,
      started: false,
      startX: event.clientX,
      startY: event.clientY
    }
    shiftElement.classList.add("is-dragging")
    this.markTargets(this.draggedShift)
    document.addEventListener("pointermove", this.pointerMoveHandler)
    document.addEventListener("pointerup", this.pointerUpHandler)
  }

  dragStart(event) {
    if (event.target.closest("button, form")) {
      event.preventDefault()
      return
    }

    const shiftElement = event.currentTarget
    this.draggedShift = this.shiftData(shiftElement)
    this.draggedShift.dragAction = this.dragAction(event)
    shiftElement.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "copyMove"
    event.dataTransfer.dropEffect = this.draggedShift.dragAction
    event.dataTransfer.setData("text/plain", this.draggedShift.id)
    this.markTargets(this.draggedShift)
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("is-dragging")
    this.draggedShift = null
    this.clearTargetMarks()
  }

  dragEnter(event) {
    if (!this.draggedShift) return

    this.markHoveredCell(event.currentTarget, this.draggedShift)
  }

  dragOver(event) {
    if (!this.draggedShift) return

    if (this.validCellForShift(event.currentTarget, this.draggedShift)) {
      event.preventDefault()
      const action = this.dragAction(event)
      this.draggedShift.dragAction = action
      event.dataTransfer.dropEffect = action
    } else {
      event.dataTransfer.dropEffect = "none"
    }
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("is-drop-hover")
  }

  drop(event) {
    if (!this.draggedShift) return

    event.preventDefault()
    const cell = event.currentTarget
    if (!this.validCellForShift(cell, this.draggedShift)) {
      this.showError("Choose another valid day for this shift.")
      return
    }

    if (this.dragAction(event) === "copy") {
      this.sendQuickEdit(this.draggedShift.copyUrl, "POST", cell.dataset.shiftDate, cell)
    } else {
      this.sendQuickEdit(this.draggedShift.moveUrl, "PATCH", cell.dataset.shiftDate, cell)
    }
  }

  optionPointerMove(event) {
    if (!this.optionPointerDrag || !this.draggedShift) return

    event.preventDefault()
    if (Math.abs(event.clientX - this.optionPointerDrag.startX) > 3 || Math.abs(event.clientY - this.optionPointerDrag.startY) > 3) {
      this.optionPointerDrag.started = true
      if (!this.optionPointerDrag.ghost) {
        this.optionPointerDrag.ghost = this.buildOptionPointerGhost(this.optionPointerDrag.shiftElement)
      }
    }
    this.moveOptionPointerGhost(event)

    this.cellTargets.forEach((cell) => cell.classList.remove("is-drop-hover"))
    const cell = this.cellFromPointer(event)
    if (cell) this.markHoveredCell(cell, this.draggedShift)
  }

  optionPointerUp(event) {
    if (!this.optionPointerDrag || !this.draggedShift) return

    event.preventDefault()
    const shift = this.draggedShift
    const cell = this.cellFromPointer(event)
    const didDrag = this.optionPointerDrag.started
    this.cleanupOptionPointerDrag()

    if (!didDrag) return

    if (!cell || !this.validCellForShift(cell, shift)) {
      this.showError("Choose another valid day for the copied shift.")
      return
    }

    this.sendQuickEdit(shift.copyUrl, "POST", cell.dataset.shiftDate, cell)
  }

  startCopy(event) {
    event.preventDefault()
    event.stopPropagation()

    const shiftElement = event.currentTarget.closest("[data-shift-id]")
    this.copyShift = this.shiftData(shiftElement)
    this.markTargets(this.copyShift)
    this.showInfo(`Copying ${this.copyShift.label}. Click another day to place the copy.`)
  }

  cancelCopy() {
    this.copyShift = null
    this.clearTargetMarks()
    this.hideMessage()
  }

  cellClick(event) {
    if (!this.copyShift) return
    if (event.target.closest("a, button, form")) return

    const cell = event.currentTarget
    if (!this.validCellForShift(cell, this.copyShift)) {
      this.showError("Choose another valid day for the copied shift.")
      this.markTargets(this.copyShift)
      return
    }

    this.sendQuickEdit(this.copyShift.copyUrl, "POST", cell.dataset.shiftDate, cell)
  }

  async sendQuickEdit(url, method, shiftDate, targetCell) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          shift: {
            shift_date: shiftDate
          }
        })
      })

      const payload = await response.json()
      if (response.ok) {
        if (payload.shift_html && targetCell) {
          this.applyQuickEdit(payload, targetCell)
        } else {
          const redirectUrl = payload.redirect_url || window.location.href
          window.location.href = redirectUrl
        }
      } else {
        this.showError(payload.error || "Shift could not be updated.")
      }
    } catch (_error) {
      this.showError("Shift could not be updated. Refresh the page and try again.")
    }
  }

  shiftData(element) {
    return {
      id: element.dataset.shiftId,
      date: element.dataset.shiftDate,
      employeeId: element.dataset.employeeId,
      positionId: element.dataset.positionId,
      label: element.dataset.shiftLabel,
      moveUrl: element.dataset.moveUrl,
      copyUrl: element.dataset.copyUrl
    }
  }

  dragAction(event) {
    return event.altKey || this.optionKeyPressed || this.draggedShift?.dragAction === "copy" ? "copy" : "move"
  }

  cellFromPointer(event) {
    return document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-schedule-quick-edit-target~='cell']")
  }

  buildOptionPointerGhost(shiftElement) {
    const ghost = shiftElement.cloneNode(true)
    const rect = shiftElement.getBoundingClientRect()
    ghost.classList.add("shift-pill-drag-ghost")
    ghost.style.width = `${rect.width}px`
    document.body.appendChild(ghost)
    return ghost
  }

  moveOptionPointerGhost(event) {
    if (!this.optionPointerDrag?.ghost) return

    const ghostRect = this.optionPointerDrag.ghost.getBoundingClientRect()
    this.optionPointerDrag.ghost.style.left = `${event.clientX - ghostRect.width / 2}px`
    this.optionPointerDrag.ghost.style.top = `${event.clientY - ghostRect.height / 2}px`
  }

  validCellForShift(cell, shift) {
    if (!cell.dataset.shiftDate || cell.dataset.shiftDate === shift.date) return false

    if (cell.dataset.viewMode === "employees") {
      return cell.dataset.employeeId === shift.employeeId
    }

    if (cell.dataset.viewMode === "positions") {
      return cell.dataset.positionId === shift.positionId
    }

    return cell.dataset.employeeId === shift.employeeId && cell.dataset.positionId === shift.positionId
  }

  markTargets(shift) {
    this.cellTargets.forEach((cell) => {
      cell.classList.toggle("is-valid-shift-target", this.validCellForShift(cell, shift))
      cell.classList.toggle("is-invalid-shift-target", !this.validCellForShift(cell, shift))
    })
  }

  markHoveredCell(cell, shift) {
    if (this.validCellForShift(cell, shift)) {
      cell.classList.add("is-drop-hover")
    }
  }

  clearTargetMarks() {
    this.cellTargets.forEach((cell) => {
      cell.classList.remove("is-valid-shift-target", "is-invalid-shift-target", "is-drop-hover")
    })
  }

  cleanupOptionPointerDrag() {
    if (this.optionPointerDrag?.shiftElement) {
      this.optionPointerDrag.shiftElement.classList.remove("is-dragging")
    }
    this.optionPointerDrag?.ghost?.remove()
    this.optionPointerDrag = null
    this.draggedShift = null
    this.clearTargetMarks()
    this.removeOptionPointerListeners()
  }

  removeOptionPointerListeners() {
    document.removeEventListener("pointermove", this.pointerMoveHandler)
    document.removeEventListener("pointerup", this.pointerUpHandler)
  }

  rememberMiniCalendarViewport(event) {
    if (event.defaultPrevented) return
    if (event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    this.storeViewport(event.currentTarget.href)
  }

  storeViewport(url) {
    try {
      const destination = new URL(url, window.location.href)
      sessionStorage.setItem("scheduleViewport", JSON.stringify({
        path: destination.pathname,
        search: destination.search,
        x: window.scrollX,
        y: window.scrollY
      }))
    } catch (_error) {
      sessionStorage.removeItem("scheduleViewport")
    }
  }

  restoreViewport() {
    try {
      const storedViewport = sessionStorage.getItem("scheduleViewport")
      if (!storedViewport) return

      const viewport = JSON.parse(storedViewport)
      if (viewport.path !== window.location.pathname || viewport.search !== window.location.search) return

      sessionStorage.removeItem("scheduleViewport")
      window.scrollTo(viewport.x || 0, viewport.y || 0)
      requestAnimationFrame(() => {
        window.scrollTo(viewport.x || 0, viewport.y || 0)
      })
    } catch (_error) {
      sessionStorage.removeItem("scheduleViewport")
    }
  }

  applyQuickEdit(payload, targetCell) {
    const template = document.createElement("template")
    template.innerHTML = payload.shift_html.trim()
    const updatedShift = template.content.firstElementChild
    if (!updatedShift) return

    if (payload.action === "move") {
      this.element.querySelector(`[data-shift-id="${CSS.escape(String(payload.shift_id))}"]`)?.remove()
    }

    const addLink = targetCell.querySelector(".schedule-add-link")
    if (addLink) {
      addLink.before(updatedShift)
    } else {
      targetCell.querySelector(".d-grid")?.append(updatedShift)
    }

    this.copyShift = null
    this.draggedShift = null
    this.clearTargetMarks()
    this.showInfo(payload.message)
  }

  showInfo(message) {
    this.showMessage(message, "info")
  }

  showError(message) {
    this.showMessage(message, "danger")
  }

  showMessage(message, kind) {
    this.alertTarget.classList.remove("d-none", "is-error")
    this.alertTarget.classList.add("d-flex")
    if (kind === "danger") this.alertTarget.classList.add("is-error")
    this.messageTarget.textContent = message
  }

  hideMessage() {
    this.alertTarget.classList.add("d-none")
    this.alertTarget.classList.remove("d-flex", "is-error")
    this.messageTarget.textContent = ""
  }
}
