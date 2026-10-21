import { createContext, useContext, useRef, useState, type ReactNode } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

// Lessons were written for a terminal (read through `less`): aligned columns, ASCII
// diagrams and 90-dash separators. Markdown would collapse that whitespace, so before
// rendering we wrap "aligned" runs of lines in text code blocks and turn dash lines into
// thematic breaks. Questions and solutions are regular markdown and skip this step.
const LIST_ITEM = /^\s*([-*+]|\d+\.)\s/
const ALIGNED = /\S {3,}\S/
const DASH_RULE = /^-{5,}\s*$/

export function prepareLesson(md: string): string {
  const out: string[] = []
  const lines = md.replace(/\r\n/g, '\n').split('\n')
  let run: string[] = []
  let inFence = false

  const flush = () => {
    if (run.length === 0) return
    const preformatted = run.some(
      (l) => ALIGNED.test(l) || (/^ {2,}\S/.test(l) && !LIST_ITEM.test(l)),
    )
    if (preformatted) out.push('```text', ...run, '```')
    else out.push(...run)
    run = []
  }

  for (const line of lines) {
    if (/^\s*```/.test(line)) {
      flush()
      inFence = !inFence
      out.push(line)
      continue
    }
    if (inFence) {
      out.push(line)
      continue
    }
    if (line.trim() === '') {
      flush()
      out.push('')
    } else if (DASH_RULE.test(line)) {
      flush()
      out.push('', '***', '')
    } else if (/^#{1,6}\s/.test(line)) {
      flush()
      out.push(line)
    } else {
      run.push(line)
    }
  }
  flush()
  return out.join('\n')
}

// useCopy: copies text and reports success for a moment ("copied" feedback).
function useCopy(): [boolean, (text: string) => Promise<void>] {
  const [copied, setCopied] = useState(false)
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1200)
    } catch {
      /* clipboard blocked: nothing to do */
    }
  }
  return [copied, copy]
}

// Code inside a <pre> is a block (copied with its button); everywhere else it's inline.
const InBlock = createContext(false)

function CodeBlock({ children }: { children?: ReactNode }) {
  const ref = useRef<HTMLPreElement>(null)
  const [copied, copy] = useCopy()
  return (
    <div className="codeblock">
      <button
        type="button"
        className="copy-btn"
        onClick={() => void copy((ref.current?.innerText ?? '').replace(/\n$/, ''))}
        title="Copy to clipboard"
      >
        {copied ? 'copied' : 'copy'}
      </button>
      <InBlock.Provider value={true}>
        <pre ref={ref}>{children}</pre>
      </InBlock.Provider>
    </div>
  )
}

// Like the real exam's question panel: one click on a name or path copies it, ready for
// Ctrl+Shift+V in the terminal. Dragging still selects part of it for a normal Ctrl+C.
function CopyableCode({ children }: { children?: ReactNode }) {
  const ref = useRef<HTMLElement>(null)
  const [copied, copy] = useCopy()
  const copyAll = () => void copy(ref.current?.textContent ?? '')
  return (
    <code
      ref={ref}
      className={copied ? 'copyable copied' : 'copyable'}
      role="button"
      tabIndex={0}
      title={copied ? 'Copied' : 'Click to copy'}
      onClick={() => {
        if (!window.getSelection()?.toString()) copyAll()
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          copyAll()
        }
      }}
    >
      {children}
    </code>
  )
}

function Code({ children, className }: { children?: ReactNode; className?: string }) {
  return useContext(InBlock) ? <code className={className}>{children}</code> : <CopyableCode>{children}</CopyableCode>
}

interface MarkdownProps {
  text: string
  lesson?: boolean
  // Inline `code` copies on click (questions, where it marks names and paths).
  copyInline?: boolean
}

export function Markdown({ text, lesson = false, copyInline = false }: MarkdownProps) {
  const source = lesson ? prepareLesson(text) : text
  return (
    <div className={lesson ? 'markdown lesson' : 'markdown'}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          pre: ({ children }) => <CodeBlock>{children}</CodeBlock>,
          ...(copyInline && { code: ({ children, className }) => <Code className={className}>{children}</Code> }),
          a: ({ href, children }) => (
            <a href={href} target="_blank" rel="noreferrer">
              {children}
            </a>
          ),
        }}
      >
        {source}
      </ReactMarkdown>
    </div>
  )
}
