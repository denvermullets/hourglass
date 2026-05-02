import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "search", "results", "team", "form", "teamInput", "projectInput"]
  static values = { url: String }

  connect() {
    this.searchTimer = null
  }

  disconnect() {
    clearTimeout(this.searchTimer)
  }

  open() {
    this.dialogTarget.showModal()
    this.searchTarget.value = ""
    this.searchTarget.focus()
    this.fetchProjects()
  }

  close() {
    this.dialogTarget.close()
  }

  search() {
    clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => this.fetchProjects(), 300)
  }

  async fetchProjects() {
    const teamId = this.teamTarget.value
    if (!teamId) {
      this.resultsTarget.innerHTML = `<div class="text-xs text-bunker-500 py-4 text-center">no team available</div>`
      return
    }

    const params = new URLSearchParams({ team_id: teamId, q: this.searchTarget.value })
    let response
    try {
      response = await fetch(`${this.urlValue}?${params}`, { headers: { Accept: "application/json" } })
    } catch (_e) {
      this.resultsTarget.innerHTML = `<div class="text-xs text-danger-400 py-4 text-center">network error</div>`
      return
    }

    let body
    try {
      body = await response.json()
    } catch (_e) {
      body = null
    }

    if (!response.ok) {
      const detail = body && body.error ? this.escape(body.error) : ""
      const hint = this.hintFor(response.status, body && body.error)
      this.resultsTarget.innerHTML = `
        <div class="text-xs text-danger-400 py-3 px-3 leading-relaxed">
          <div class="font-dm-mono uppercase tracking-[0.1em] text-[10px] mb-1">// load failed (${response.status})</div>
          ${detail ? `<div class="text-bunker-300">${detail}</div>` : ""}
          ${hint ? `<div class="text-bunker-500 mt-1 text-[11px]">${hint}</div>` : ""}
        </div>
      `
      return
    }

    if (!Array.isArray(body) || body.length === 0) {
      this.resultsTarget.innerHTML = `<div class="text-xs text-bunker-500 py-4 text-center">no matching projects</div>`
      return
    }

    this.resultsTarget.innerHTML = body.map(p => this.row(p)).join("")
  }

  row(p) {
    const id = String(p.id)
    const ident = p.identifier ? `<span class="font-dm-mono text-[11px] text-bunker-500 mr-2">${this.escape(p.identifier)}</span>` : ""
    const desc = p.description ? `<div class="text-[11px] text-bunker-500 truncate">${this.escape(p.description)}</div>` : ""
    return `
      <button type="button" data-action="project-picker#pick" data-id="${id}"
              class="text-left rounded px-3 py-2 cursor-pointer bg-transparent border border-transparent hover:border-bunker-775 hover:bg-bunker-875 transition-colors duration-100 w-full">
        <div class="flex items-baseline gap-1">
          ${ident}
          <span class="text-xs text-bunker-50">${this.escape(p.name || "")}</span>
        </div>
        ${desc}
      </button>
    `
  }

  pick(event) {
    const id = event.currentTarget.dataset.id
    this.projectInputTarget.value = id
    this.teamInputTarget.value = this.teamTarget.value
    this.formTarget.requestSubmit()
  }

  hintFor(status, errorMessage) {
    const msg = (errorMessage || "").toLowerCase()
    if (msg.includes("rejected token") || msg.includes("unauthorized") || msg.includes("401") || msg.includes("403")) {
      return "mtasks rejected the API token &mdash; regenerate it in mtasks and paste the new value in server settings &rarr; integrations."
    }
    if (msg.includes("connection failed") || msg.includes("connection refused") || msg.includes("timeout")) {
      return "hourglass couldn't reach mtasks &mdash; check the integration's base_url and that mtasks is running."
    }
    if (msg.includes("404") || msg.includes("not found")) {
      return "team or endpoint not found on mtasks &mdash; the team may have been removed."
    }
    if (status === 502) {
      return "the upstream JAIT call failed &mdash; check the integration token + base url."
    }
    return ""
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]))
  }
}
