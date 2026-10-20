import { useRef, useState, type ReactNode } from 'react'
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

function CodeBlock({ children }: { children?: ReactNode }) {
  const ref = useRef<HTMLPreElement>(null)
  const [copied, setCopied] = useState(false)
  const copy = async () => {
    const text = ref.current?.innerText ?? ''
    try {
      await navigator.clipboard.writeText(text.replace(/\n$/, ''))
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1200)
    } catch {
      /* clipboard blocked: nothing to do */
    }
  }
  return (
    <div className="codeblock">
      <button type="button" className="copy-btn" onClick={copy} title="Copy to clipboard">
        {copied ? 'copied' : 'copy'}
      </button>
      <pre ref={ref}>{children}</pre>
    </div>
  )
}

export function Markdown({ text, lesson = false }: { text: string; lesson?: boolean }) {
  const source = lesson ? prepareLesson(text) : text
  return (
    <div className={lesson ? 'markdown lesson' : 'markdown'}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          pre: ({ children }) => <CodeBlock>{children}</CodeBlock>,
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
