// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/threadifi"
import topbar from "../vendor/topbar"
import hljs from "highlight.js/lib/core"
import bash from "highlight.js/lib/languages/bash"
import css from "highlight.js/lib/languages/css"
import elixir from "highlight.js/lib/languages/elixir"
import go from "highlight.js/lib/languages/go"
import html from "highlight.js/lib/languages/xml"
import javascript from "highlight.js/lib/languages/javascript"
import python from "highlight.js/lib/languages/python"
import ruby from "highlight.js/lib/languages/ruby"
import rust from "highlight.js/lib/languages/rust"
import sql from "highlight.js/lib/languages/sql"
import typescript from "highlight.js/lib/languages/typescript"

const ChannelMessages = {
  mounted() {
    this.atBottom = true
    this.indicator = this.el.querySelector(".new-message-indicator")

    this.handleEvent("new_message", () => this.onNewMessage())
    this.el.addEventListener("scroll", () => this.updateScrollState())

    if (this.indicator) {
      this.indicator.addEventListener("click", () => {
        this.scrollToBottom()
        this.hideIndicator()
      })
    }

    this.scrollToBottom()
  },
  updated() {
    this.onNewMessage()
  },
  onNewMessage() {
    if (this.isNearBottom()) {
      this.scrollToBottom()
      this.hideIndicator()
    } else {
      this.showIndicator()
    }
  },
  updateScrollState() {
    this.atBottom = this.isNearBottom()
    if (this.atBottom) {
      this.hideIndicator()
    }
  },
  isNearBottom() {
    return this.el.scrollTop + this.el.clientHeight >= this.el.scrollHeight - 24
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  },
  showIndicator() {
    if (this.indicator) {
      this.indicator.classList.remove("hidden")
      this.indicator.classList.add("flex")
    }
  },
  hideIndicator() {
    if (this.indicator) {
      this.indicator.classList.add("hidden")
      this.indicator.classList.remove("flex")
    }
  },
}

hljs.registerLanguage("bash", bash)
hljs.registerLanguage("css", css)
hljs.registerLanguage("elixir", elixir)
hljs.registerLanguage("go", go)
hljs.registerLanguage("html", html)
hljs.registerLanguage("javascript", javascript)
hljs.registerLanguage("python", python)
hljs.registerLanguage("ruby", ruby)
hljs.registerLanguage("rust", rust)
hljs.registerLanguage("sql", sql)
hljs.registerLanguage("typescript", typescript)

const MessageComposer = {
  mounted() {
    this.el.addEventListener("keydown", (event) => {
      if (this.el.value.trim() === "/snippet" && (event.key === "Enter" || event.key === " ")) {
        event.preventDefault()
        this.el.value = ""
        this.pushEvent("open_snippet_modal", {})
        return
      }

      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault()
        let form = this.el.closest("form")
        if (form) {
          form.requestSubmit()
        }
      }
    })
  },
}

const SnippetCopy = {
  mounted() {
    this.el.addEventListener("click", () => {
      let targetId = this.el.dataset.target
      if (!targetId) return
      let code = document.getElementById(targetId)
      if (!code) return
      navigator.clipboard.writeText(code.innerText || "")
      const label = this.el.querySelector(".copy-label")
      if (!label) return
      label.textContent = "Copied"
      setTimeout(() => {
        label.textContent = "Copy"
      }, 1500)
    })
  },
}

const SnippetHighlight = {
  mounted() {
    hljs.highlightElement(this.el)
  },
  updated() {
    hljs.highlightElement(this.el)
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ChannelMessages, MessageComposer, SnippetCopy, SnippetHighlight},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
