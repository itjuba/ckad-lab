import type { ReactNode } from 'react'
import type { CheckResult, Domain, Mode, Question } from '../api'
import { CopyableCode, Markdown } from './Markdown'
import { Spinner } from './Modal'

export type Tab = 'question' | 'lesson' | 'solution'

export type View = { kind: 'question'; n: number } | { kind: 'lesson0' }

interface Props {
  mode: Mode
  view: View
  question: Question | null
  questionError: string | null
  domain: Domain | undefined
  // Task weight in percent: the exact share of the running exam, or in practice the weight
  // itself (about its share of an 18-question exam).
  weightPct: number | null
  flagged: boolean
  onToggleFlag: (() => void) | null // exam only
  examIndex: number | null
  examCount: number
  tab: Tab
  onTab: (t: Tab) => void
  lessonText: string | null
  lessonError: string | null
  solutionText: string | null
  solutionError: string | null
  solutionRevealed: boolean
  onRevealSolution: () => void
  lesson0Text: string | null
  lesson0Error: string | null
  check: CheckResult | null
  checkError: string | null
  checking: boolean
  resetting: boolean
  resetMessage: { ok: boolean; text: string } | null
  onCheck: () => void
  onReset: () => void
  onPrev: (() => void) | null
  onNext: (() => void) | null
  nextLabel: string
  onOpenQuestion: (n: number) => void
  onDismissCheck: () => void
}

function Loading({ what }: { what: string }) {
  return (
    <div className="placeholder">
      <Spinner /> Loading {what}…
    </div>
  )
}

function ErrorBox({ text }: { text: string }) {
  return <div className="error-box">{text}</div>
}

// Like the real exam, every question starts with the context to work in.
function ContextLine({ context }: { context: string }) {
  if (!context) return null
  return (
    <div className="context-line">
      <span>Set configuration context:</span>
      <CopyableCode>kubectl config use-context {context}</CopyableCode>
    </div>
  )
}

export function QuestionPanel(p: Props) {
  const inExam = p.mode === 'exam'
  const isLesson0 = p.view.kind === 'lesson0'

  let content: ReactNode
  if (isLesson0) {
    content = p.lesson0Error ? (
      <ErrorBox text={p.lesson0Error} />
    ) : p.lesson0Text === null ? (
      <Loading what="Lesson 0" />
    ) : (
      <Markdown text={p.lesson0Text} lesson />
    )
  } else if (p.tab === 'lesson') {
    content = p.lessonError ? (
      <ErrorBox text={p.lessonError} />
    ) : p.lessonText === null ? (
      <Loading what="the lesson" />
    ) : (
      <Markdown text={p.lessonText} lesson />
    )
  } else if (p.tab === 'solution') {
    if (!p.solutionRevealed) {
      content = (
        <div className="reveal">
          <p>Try the question on your own first. Looking at the solution too early makes it stick less.</p>
          <button type="button" className="btn primary" onClick={p.onRevealSolution}>
            Show the solution
          </button>
        </div>
      )
    } else {
      content = p.solutionError ? (
        <ErrorBox text={p.solutionError} />
      ) : p.solutionText === null ? (
        <Loading what="the solution" />
      ) : (
        <>
          <ContextLine context={p.question?.context ?? ''} />
          <Markdown text={p.solutionText} />
        </>
      )
    }
  } else {
    content = p.questionError ? (
      <ErrorBox text={p.questionError} />
    ) : p.question === null ? (
      <Loading what="the question" />
    ) : (
      <>
        <ContextLine context={p.question.context} />
        <Markdown text={p.question.markdown} copyInline />
      </>
    )
  }

  const n = p.view.kind === 'question' ? p.view.n : 0

  return (
    <section className="question-panel" aria-label="Question">
      <header className="q-head">
        {isLesson0 ? (
          <>
            <span className="q-num">Lesson 0</span>
            <h1 className="q-title">Kubernetes &amp; kubectl fundamentals</h1>
          </>
        ) : (
          <>
            <span className="q-num">Q{n}</span>
            <h1 className="q-title">{p.question?.title ?? '…'}</h1>
            <div className="q-meta">
              {p.domain && (
                <span className="chip" title={p.domain.name}>
                  {p.domain.short} · {p.domain.weight}%
                </span>
              )}
              {p.weightPct !== null && (
                <span className="weight" title="This question's share of the exam score (partial credit per task)">
                  Task weight: {p.weightPct}%
                </span>
              )}
              {inExam && p.examIndex !== null && (
                <span className="muted">
                  Exam question {p.examIndex + 1} of {p.examCount}
                </span>
              )}
              {!inExam && p.question?.step != null && (
                <span className="muted">
                  Step {p.question.step} of {p.question.steps}
                </span>
              )}
              {p.onToggleFlag && (
                <button
                  type="button"
                  className={p.flagged ? 'btn tiny flag on' : 'btn tiny ghost flag'}
                  aria-pressed={p.flagged}
                  onClick={p.onToggleFlag}
                  title="Flag this question to come back to it later (the list shows ⚑)"
                >
                  ⚑ {p.flagged ? 'Flagged' : 'Flag'}
                </button>
              )}
            </div>
          </>
        )}
      </header>

      {!isLesson0 && (
        <nav className="tabs" role="tablist">
          <button
            type="button"
            role="tab"
            aria-selected={p.tab === 'question'}
            className={p.tab === 'question' ? 'tab active' : 'tab'}
            onClick={() => p.onTab('question')}
          >
            Question
          </button>
          {!inExam && (
            <>
              <button
                type="button"
                role="tab"
                aria-selected={p.tab === 'lesson'}
                className={p.tab === 'lesson' ? 'tab active' : 'tab'}
                onClick={() => p.onTab('lesson')}
              >
                Lesson
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={p.tab === 'solution'}
                className={p.tab === 'solution' ? 'tab active' : 'tab'}
                onClick={() => p.onTab('solution')}
              >
                Solution
              </button>
            </>
          )}
        </nav>
      )}

      <div className="q-content">{content}</div>

      {!isLesson0 && (p.check || p.checkError || p.resetMessage) && (
        <div className="results" aria-live="polite">
          {p.resetMessage && (
            <div className={p.resetMessage.ok ? 'notice ok' : 'error-box'}>
              {p.resetMessage.ok ? (
                p.resetMessage.text
              ) : (
                <>
                  <strong>Reset failed.</strong>
                  <pre className="log">{p.resetMessage.text}</pre>
                </>
              )}
            </div>
          )}
          {p.checkError && <ErrorBox text={p.checkError} />}
          {p.check && (
            <>
              <div className="results-head">
                <strong>
                  {p.check.pass}/{p.check.total} tasks
                </strong>
                <button type="button" className="icon-btn" onClick={p.onDismissCheck} aria-label="Hide results">
                  ✕
                </button>
              </div>
              <ul className="tasks">
                {p.check.tasks.map((t, i) => (
                  <li key={i} className={t.ok ? 'task ok' : 'task ko'}>
                    <span className="mark">{t.ok ? '✔' : '✘'}</span>
                    <span>{t.text}</span>
                  </li>
                ))}
              </ul>
              {p.check.passed && (
                <div className="passed-banner">
                  <span>Passed!</span>
                  {p.check.next !== null && p.check.next !== n && (
                    <button type="button" className="btn primary small" onClick={() => p.onOpenQuestion(p.check!.next!)}>
                      Next: Q{p.check.next}
                    </button>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      )}

      <footer className="actions">
        {!isLesson0 && (
          <>
            <button
              type="button"
              className="btn primary"
              onClick={p.onCheck}
              disabled={inExam || p.checking || p.resetting}
              title={inExam ? 'Exam mode: graded at the end' : 'Grade this question (Ctrl+Enter)'}
            >
              {p.checking ? (
                <>
                  <Spinner /> Checking…
                </>
              ) : (
                'Check'
              )}
            </button>
            <button
              type="button"
              className="btn ghost"
              onClick={p.onReset}
              disabled={p.checking || p.resetting}
              title="Put this question back to its starting state"
            >
              {p.resetting ? (
                <>
                  <Spinner /> Resetting…
                </>
              ) : (
                'Reset'
              )}
            </button>
          </>
        )}
        <span className="spacer" />
        <button type="button" className="btn ghost" onClick={p.onPrev ?? undefined} disabled={!p.onPrev} title="Previous (Alt+←)">
          ◀ Prev
        </button>
        <button type="button" className="btn ghost" onClick={p.onNext ?? undefined} disabled={!p.onNext} title="Next (Alt+→)">
          {p.nextLabel} ▶
        </button>
      </footer>
    </section>
  )
}
