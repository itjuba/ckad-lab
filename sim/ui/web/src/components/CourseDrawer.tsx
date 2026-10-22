import { useEffect, useRef } from 'react'
import type { Course, Mode } from '../api'
import type { View } from './QuestionPanel'

interface Props {
  open: boolean
  onClose: () => void
  mode: Mode
  course: Course | null
  passed: Set<number>
  next: number | null
  examQuestions: number[]
  flags: Set<number>
  weightPct: (n: number) => number | null
  titles: Map<number, string>
  current: View
  onOpenQuestion: (n: number) => void
  onOpenLesson0: () => void
}

export function CourseDrawer(p: Props) {
  useEffect(() => {
    if (!p.open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') p.onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [p.open, p.onClose])

  // While closed (slid off screen) the drawer must not take focus or clicks. React 18 has
  // no `inert` prop, so it's set on the element directly.
  const asideRef = useRef<HTMLElement>(null)
  useEffect(() => {
    asideRef.current?.toggleAttribute('inert', !p.open)
  }, [p.open])

  const isCurrent = (n: number) => p.current.kind === 'question' && p.current.n === n
  const inExam = p.mode === 'exam'

  return (
    <>
      <div className={p.open ? 'drawer-backdrop open' : 'drawer-backdrop'} onClick={p.onClose} />
      <aside ref={asideRef} className={p.open ? 'drawer open' : 'drawer'} aria-hidden={!p.open} aria-label="Course">
        <div className="drawer-head">
          <h2>{inExam ? 'Exam questions' : 'Course'}</h2>
          <button type="button" className="icon-btn" onClick={p.onClose} aria-label="Close">
            ✕
          </button>
        </div>
        <div className="drawer-body">
          {inExam ? (
            <ol className="exam-list">
              {p.examQuestions.map((n, i) => {
                const w = p.weightPct(n)
                const flagged = p.flags.has(n)
                return (
                  <li key={n}>
                    <button
                      type="button"
                      className={isCurrent(n) ? 'drawer-item current' : 'drawer-item'}
                      onClick={() => p.onOpenQuestion(n)}
                    >
                      <span className="status num">{i + 1}.</span>
                      <span className="item-text">
                        <span className="item-title">
                          Q{n} {p.titles.get(n) ?? ''}
                        </span>
                        <span className="item-sub">
                          {w !== null && `Task weight ${w}%`}
                          {flagged && <span className="flagged"> · ⚑ flagged</span>}
                        </span>
                      </span>
                    </button>
                  </li>
                )
              })}
            </ol>
          ) : !p.course ? (
            <p className="muted pad">Loading the course…</p>
          ) : (
            <>
              <button
                type="button"
                className={p.current.kind === 'lesson0' ? 'drawer-item lesson0 current' : 'drawer-item lesson0'}
                onClick={p.onOpenLesson0}
              >
                <span className="status">★</span>
                <span className="item-text">
                  <span className="item-title">Lesson 0: {p.course.lesson0.title}</span>
                  <span className="item-sub">Start here if Kubernetes is new to you</span>
                </span>
              </button>
              {p.course.sections.map((s) => (
                <div key={s.title} className="section">
                  <h3>{s.title}</h3>
                  <ul>
                    {s.questions.map((q) => {
                      const done = p.passed.has(q.n)
                      const isNext = !done && q.n === p.next
                      return (
                        <li key={q.n}>
                          <button
                            type="button"
                            className={isCurrent(q.n) ? 'drawer-item current' : 'drawer-item'}
                            onClick={() => p.onOpenQuestion(q.n)}
                          >
                            <span className={done ? 'status done' : isNext ? 'status next' : 'status'}>
                              {done ? '✔' : isNext ? '▶' : '·'}
                            </span>
                            <span className="item-text">
                              <span className="item-title">
                                Q{q.n} {q.title}
                              </span>
                              <span className="item-sub">{q.lesson}</span>
                            </span>
                          </button>
                        </li>
                      )
                    })}
                  </ul>
                </div>
              ))}
            </>
          )}
        </div>
      </aside>
    </>
  )
}
