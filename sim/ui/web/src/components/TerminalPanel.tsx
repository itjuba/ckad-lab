import { useCallback, useEffect, useRef, useState } from 'react'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import { WebLinksAddon } from '@xterm/addon-web-links'
import { terminalUrl } from '../api'
import { useStored } from '../hooks'

const FONT = '"JetBrains Mono", "Cascadia Code", "Fira Code", Menlo, Consolas, "DejaVu Sans Mono", monospace'

const THEME = {
  background: '#0d1117',
  foreground: '#e6edf3',
  cursor: '#58a6ff',
  cursorAccent: '#0d1117',
  selectionBackground: '#264f78',
  black: '#484f58',
  red: '#ff7b72',
  green: '#3fb950',
  yellow: '#d29922',
  blue: '#58a6ff',
  magenta: '#bc8cff',
  cyan: '#39c5cf',
  white: '#b1bac4',
  brightBlack: '#6e7681',
  brightRed: '#ffa198',
  brightGreen: '#56d364',
  brightYellow: '#e3b341',
  brightBlue: '#79c0ff',
  brightMagenta: '#d2a8ff',
  brightCyan: '#56d4dd',
  brightWhite: '#ffffff',
}

// Keys the app handles itself (Check / Prev / Next); the terminal must ignore them.
export function isAppShortcut(e: KeyboardEvent): boolean {
  if (e.ctrlKey && !e.shiftKey && !e.altKey && e.key === 'Enter') return true
  if (e.altKey && !e.ctrlKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) return true
  return false
}

export function TerminalPanel() {
  const hostRef = useRef<HTMLDivElement>(null)
  const termRef = useRef<Terminal | null>(null)
  const fitRef = useRef<FitAddon | null>(null)
  const wsRef = useRef<WebSocket | null>(null)
  const [status, setStatus] = useState<'connecting' | 'open' | 'closed'>('connecting')
  const [fontSize, setFontSize] = useStored<number>('ckad.termFontSize', 14)

  const sendResize = useCallback(() => {
    const term = termRef.current
    const ws = wsRef.current
    if (term && ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }))
    }
  }, [])

  const fit = useCallback(() => {
    try {
      fitRef.current?.fit()
    } catch {
      /* the panel can be hidden for a moment; fitting then throws */
    }
  }, [])

  const connect = useCallback(() => {
    const term = termRef.current
    if (!term) return
    const old = wsRef.current
    if (old) {
      old.onclose = null
      old.close()
    }
    term.reset()
    setStatus('connecting')
    const ws = new WebSocket(terminalUrl())
    ws.binaryType = 'arraybuffer'
    wsRef.current = ws
    ws.onopen = () => {
      setStatus('open')
      fit()
      sendResize()
      term.focus()
    }
    ws.onmessage = (ev) => {
      if (ev.data instanceof ArrayBuffer) term.write(new Uint8Array(ev.data))
      else term.write(String(ev.data))
    }
    ws.onclose = () => {
      if (wsRef.current === ws) setStatus('closed')
    }
    ws.onerror = () => {
      /* onclose follows and shows the reconnect overlay */
    }
  }, [fit, sendResize])

  // Create the terminal once.
  useEffect(() => {
    const host = hostRef.current
    if (!host) return
    const term = new Terminal({
      fontFamily: FONT,
      fontSize,
      cursorBlink: true,
      scrollback: 5000,
      theme: THEME,
      allowProposedApi: false,
    })
    const fitAddon = new FitAddon()
    term.loadAddon(fitAddon)
    term.loadAddon(new WebLinksAddon())
    term.open(host)
    termRef.current = term
    fitRef.current = fitAddon

    term.attachCustomKeyEventHandler((e) => {
      if (isAppShortcut(e)) return false
      // Exam-style copy/paste: Ctrl+Shift+C copies the selection, Ctrl+Shift+V pastes.
      if (e.type === 'keydown' && e.ctrlKey && e.shiftKey && (e.key === 'C' || e.key === 'c')) {
        if (term.hasSelection()) {
          void navigator.clipboard?.writeText(term.getSelection()).catch(() => undefined)
          e.preventDefault()
          return false
        }
      }
      if (e.type === 'keydown' && e.ctrlKey && e.shiftKey && (e.key === 'V' || e.key === 'v')) {
        e.preventDefault()
        void navigator.clipboard
          ?.readText()
          .then((t) => term.paste(t))
          .catch(() => undefined)
        return false
      }
      return true
    })

    const dataSub = term.onData((data) => {
      const ws = wsRef.current
      if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: 'input', data }))
    })
    const resizeSub = term.onResize(() => sendResize())

    let timer = 0
    const observer = new ResizeObserver(() => {
      window.clearTimeout(timer)
      timer = window.setTimeout(fit, 80)
    })
    observer.observe(host)
    fit()
    connect()

    return () => {
      observer.disconnect()
      window.clearTimeout(timer)
      dataSub.dispose()
      resizeSub.dispose()
      const ws = wsRef.current
      if (ws) {
        ws.onclose = null
        ws.close()
      }
      wsRef.current = null
      term.dispose()
      termRef.current = null
      fitRef.current = null
    }
    // Created once on purpose: fontSize changes are applied by the effect below.
  }, [])

  useEffect(() => {
    const term = termRef.current
    if (!term) return
    term.options.fontSize = fontSize
    fit()
  }, [fontSize, fit])

  return (
    <section className="terminal-panel" aria-label="Terminal">
      <div className="term-toolbar">
        <span className="term-title">
          <span className={`dot ${status}`} /> Terminal
        </span>
        <span className="term-hint">Copy: select + Ctrl+Shift+C · Paste: Ctrl+Shift+V</span>
        <div className="term-actions">
          <button type="button" className="btn tiny ghost" onClick={() => setFontSize((s) => Math.max(10, s - 1))} title="Smaller font">
            A−
          </button>
          <button type="button" className="btn tiny ghost" onClick={() => setFontSize((s) => Math.min(24, s + 1))} title="Bigger font">
            A+
          </button>
          <button type="button" className="btn tiny ghost" onClick={connect} title="Start a fresh shell">
            New session
          </button>
        </div>
      </div>
      <div className="term-body" onMouseDown={() => termRef.current?.focus()}>
        <div className="term-host" ref={hostRef} />
        {status === 'closed' && (
          <div className="term-overlay">
            <p>Disconnected from the terminal.</p>
            <button type="button" className="btn primary" onClick={connect}>
              Reconnect
            </button>
          </div>
        )}
        {status === 'connecting' && <div className="term-connecting">Connecting…</div>}
      </div>
    </section>
  )
}
