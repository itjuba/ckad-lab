import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type MouseEvent as ReactMouseEvent } from 'react'
import { api, errorMessage, type CheckResult, type Course, type ExamResult, type Question, type State } from './api'
import { useLatest, useNow, useStored } from './hooks'
import { TopBar } from './components/TopBar'
import { QuestionPanel, type Tab, type View } from './components/QuestionPanel'
import { TerminalPanel, isAppShortcut } from './components/TerminalPanel'
import { CourseDrawer } from './components/CourseDrawer'
import { ConfirmDialog } from './components/Modal'
import { ExamResultsModal, HistoryModal, StartExamDialog } from './components/ExamModals'

type Dict<T> = Record<number, T>

export default function App() {
  // ---- server data -------------------------------------------------------------------
  const [state, setState] = useState<State | null>(null)
  const [stateError, setStateError] = useState<string | null>(null)
  const [course, setCourse] = useState<Course | null>(null)

  // ---- persisted UI preferences -------------------------------------------------------
  const [theme, setTheme] = useStored<'dark' | 'light'>('ckad.theme', 'dark')
  const [leftPct, setLeftPct] = useStored<number>('ckad.leftPct', 42)
  const [lastView, setLastView] = useStored<View | null>('ckad.lastView', null)
  const [hintDismissed, setHintDismissed] = useStored<boolean>('ckad.hintDismissed', false)

  // ---- what's on screen ---------------------------------------------------------------
  const [view, setView] = useState<View | null>(null)
  const [tab, setTab] = useState<Tab>('question')
  const [questions, setQuestions] = useState<Dict<Question>>({})
  const [questionErrors, setQuestionErrors] = useState<Dict<string>>({})
  const [lessons, setLessons] = useState<Dict<string>>({})
  const [lessonErrors, setLessonErrors] = useState<Dict<string>>({})
  const [solutions, setSolutions] = useState<Dict<string>>({})
  const [solutionErrors, setSolutionErrors] = useState<Dict<string>>({})
  const [revealed, setRevealed] = useState<Set<number>>(new Set())
  const [checks, setChecks] = useState<Dict<CheckResult>>({})
  const [checkErrors, setCheckErrors] = useState<Dict<string>>({})
  const [resetMessages, setResetMessages] = useState<Dict<{ ok: boolean; text: string }>>({})
  const [checking, setChecking] = useState<number | null>(null)
  const [resetting, setResetting] = useState<number | null>(null)

  // ---- dialogs ------------------------------------------------------------------------
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [startOpen, setStartOpen] = useState(false)
  const [startBusy, setStartBusy] = useState(false)
  const [startError, setStartError] = useState<string | null>(null)
  const [endConfirm, setEndConfirm] = useState(false)
  const [endBusy, setEndBusy] = useState(false)
  const [endError, setEndError] = useState<string | null>(null)
  const [abortConfirm, setAbortConfirm] = useState(false)
  const [abortBusy, setAbortBusy] = useState(false)
  const [resetConfirm, setResetConfirm] = useState<number | null>(null)
  const [result, setResult] = useState<ExamResult | null>(null)
  const [historyOpen, setHistoryOpen] = useState(false)
  const [toast, setToast] = useState<string | null>(null)

  const inExam = state?.mode === 'exam'
  const now = useNow(!!inExam)

  useEffect(() => {
    document.documentElement.dataset.theme = theme
  }, [theme])

  // ---- loading and polling ------------------------------------------------------------
  // The course is static: it's loaded once, on the first poll that reaches the server, so
  // the page recovers on its own when it was opened while the simulator was down.
  const courseLoaded = useRef(false)
  const refreshState = useCallback(async () => {
    try {
      const s = await api.state()
      if (!courseLoaded.current) {
        setCourse(await api.course())
        courseLoaded.current = true
      }
      setState(s)
      setStateError(null)
      return s
    } catch (e) {
      setStateError(errorMessage(e))
      return null
    }
  }, [])

  useEffect(() => {
    void refreshState()
    const id = window.setInterval(() => void refreshState(), 10_000)
    return () => window.clearInterval(id)
  }, [refreshState])

  useEffect(() => {
    if (!toast) return
    const id = window.setTimeout(() => setToast(null), 3500)
    return () => window.clearTimeout(id)
  }, [toast])

  // ---- derived data -------------------------------------------------------------------
  const titles = useMemo(() => {
    const m = new Map<number, string>()
    course?.sections.forEach((s) => s.questions.forEach((q) => m.set(q.n, q.title)))
    return m
  }, [course])

  const learningOrder = useMemo(
    () => (course ? course.sections.flatMap((s) => s.questions.map((q) => q.n)) : []),
    [course],
  )
  const order = inExam ? state?.examQuestions ?? [] : learningOrder
  const passed = useMemo(() => new Set(state?.passed ?? []), [state?.passed])
  const flags = useMemo(() => new Set(state?.flags ?? []), [state?.flags])

  // Task weights, like the exam shows them: during an exam, each question's exact share of
  // that exam; in practice, the weight itself (about its share of an 18-question exam).
  const weights = useMemo(() => {
    const m = new Map<number, number>()
    course?.sections.forEach((s) => s.questions.forEach((q) => m.set(q.n, q.weight)))
    return m
  }, [course])
  const examQuestions = state?.examQuestions
  const weightPct = useCallback(
    (n: number): number | null => {
      const w = weights.get(n)
      if (w === undefined) return null
      if (!inExam) return w
      const total = (examQuestions ?? []).reduce((sum, x) => sum + (weights.get(x) ?? 0), 0)
      return total > 0 ? Math.round((w * 100) / total) : null
    },
    [weights, inExam, examQuestions],
  )

  // ---- navigation ---------------------------------------------------------------------
  const openQuestion = useCallback(
    (n: number) => {
      const v: View = { kind: 'question', n }
      setView(v)
      setLastView(v)
      setTab('question')
      setDrawerOpen(false)
    },
    [setLastView],
  )

  const openLesson0 = useCallback(() => {
    const v: View = { kind: 'lesson0' }
    setView(v)
    setLastView(v)
    setDrawerOpen(false)
  }, [setLastView])

  // Pick the first view once state and course are known.
  const initialized = useRef(false)
  useEffect(() => {
    if (initialized.current || !state || !course) return
    initialized.current = true
    const valid = (v: View | null): v is View =>
      !!v && (v.kind === 'lesson0' ? state.mode === 'learn' : titles.has(v.n))
    if (state.mode === 'exam') {
      const first = state.examQuestions[0]
      if (lastView?.kind === 'question' && state.examQuestions.includes(lastView.n)) setView(lastView)
      else if (first !== undefined) setView({ kind: 'question', n: first })
    } else if (valid(lastView)) {
      setView(lastView)
    } else {
      const n = state.next ?? learningOrder[0]
      if (n !== undefined) setView({ kind: 'question', n })
    }
  }, [state, course, titles, lastView, learningOrder])

  // Follow mode switches made here or in the CLI.
  const prevMode = useRef<string | null>(null)
  useEffect(() => {
    if (!state) return
    const before = prevMode.current
    prevMode.current = state.mode
    if (before === null || before === state.mode) return
    if (state.mode === 'exam') {
      setChecks({})
      setCheckErrors({})
      setResetMessages({})
      const first = state.examQuestions[0]
      if (first !== undefined) openQuestion(first)
    }
  }, [state, openQuestion])

  useEffect(() => {
    if (inExam && tab !== 'question') setTab('question')
    if (inExam && view?.kind === 'lesson0') {
      const first = state?.examQuestions[0]
      if (first !== undefined) setView({ kind: 'question', n: first })
    }
  }, [inExam, tab, view, state?.examQuestions])

  // ---- lazy content loading -----------------------------------------------------------
  const currentN = view?.kind === 'question' ? view.n : null

  useEffect(() => {
    if (currentN === null || questions[currentN]) return
    api
      .question(currentN)
      .then((q) => {
        setQuestions((m) => ({ ...m, [currentN]: q }))
        setQuestionErrors((m) => {
          const { [currentN]: _drop, ...rest } = m
          void _drop
          return rest
        })
      })
      .catch((e) => setQuestionErrors((m) => ({ ...m, [currentN]: errorMessage(e) })))
  }, [currentN, questions])

  useEffect(() => {
    if (currentN === null || tab !== 'lesson' || lessons[currentN] !== undefined) return
    api
      .lesson(currentN)
      .then((r) => setLessons((m) => ({ ...m, [currentN]: r.markdown })))
      .catch((e) => setLessonErrors((m) => ({ ...m, [currentN]: errorMessage(e) })))
  }, [currentN, tab, lessons])

  useEffect(() => {
    if (view?.kind !== 'lesson0' || lessons[0] !== undefined) return
    api
      .lesson(0)
      .then((r) => setLessons((m) => ({ ...m, 0: r.markdown })))
      .catch((e) => setLessonErrors((m) => ({ ...m, 0: errorMessage(e) })))
  }, [view, lessons])

  useEffect(() => {
    if (currentN === null || tab !== 'solution' || !revealed.has(currentN) || solutions[currentN] !== undefined) return
    api
      .solution(currentN)
      .then((r) => setSolutions((m) => ({ ...m, [currentN]: r.markdown })))
      .catch((e) => setSolutionErrors((m) => ({ ...m, [currentN]: errorMessage(e) })))
  }, [currentN, tab, revealed, solutions])

  // ---- actions ------------------------------------------------------------------------
  const doCheck = useCallback(async () => {
    if (currentN === null || inExam || checking !== null || resetting !== null) return
    const n = currentN
    setChecking(n)
    setCheckErrors((m) => ({ ...m, [n]: '' }))
    setResetMessages((m) => {
      const { [n]: _drop, ...rest } = m
      void _drop
      return rest
    })
    try {
      const r = await api.check(n)
      setChecks((m) => ({ ...m, [n]: r }))
      if (r.passed) setToast(`Q${n} passed!`)
      void refreshState()
    } catch (e) {
      setCheckErrors((m) => ({ ...m, [n]: errorMessage(e) }))
    } finally {
      setChecking(null)
    }
  }, [currentN, inExam, checking, resetting, refreshState])

  const doReset = useCallback(async (n: number) => {
    setResetting(n)
    setResetConfirm(null)
    setChecks((m) => {
      const { [n]: _drop, ...rest } = m
      void _drop
      return rest
    })
    setCheckErrors((m) => ({ ...m, [n]: '' }))
    try {
      const r = await api.reset(n)
      setResetMessages((m) => ({
        ...m,
        [n]: r.ok
          ? { ok: true, text: `Q${n} is back to its starting state.` }
          : { ok: false, text: r.log || 'The setup script failed.' },
      }))
    } catch (e) {
      setResetMessages((m) => ({ ...m, [n]: { ok: false, text: errorMessage(e) } }))
    } finally {
      setResetting(null)
    }
  }, [])

  const startExam = useCallback(
    async (keep: boolean) => {
      setStartBusy(true)
      setStartError(null)
      try {
        const s = await api.examStart(keep)
        setState(s)
        setStartOpen(false)
        setChecks({})
        setCheckErrors({})
        setResetMessages({})
        prevMode.current = s.mode
        const first = s.examQuestions[0]
        if (first !== undefined) openQuestion(first)
        setToast('Mock exam started. Good luck!')
      } catch (e) {
        setStartError(errorMessage(e))
      } finally {
        setStartBusy(false)
      }
    },
    [openQuestion],
  )

  const endExam = useCallback(async () => {
    setEndBusy(true)
    setEndError(null)
    try {
      const r = await api.examEnd()
      setResult(r)
      setEndConfirm(false)
      void refreshState()
    } catch (e) {
      setEndError(errorMessage(e))
    } finally {
      setEndBusy(false)
    }
  }, [refreshState])

  const toggleFlag = useCallback(async () => {
    if (currentN === null || !inExam) return
    const n = currentN
    try {
      setState(await api.flag(n, !flags.has(n)))
    } catch (e) {
      setToast(errorMessage(e))
    }
  }, [currentN, inExam, flags])

  const abortExam = useCallback(async () => {
    setAbortBusy(true)
    try {
      await api.examAbort()
      setAbortConfirm(false)
      setToast('Exam stopped without grading.')
      void refreshState()
    } catch (e) {
      setToast(errorMessage(e))
    } finally {
      setAbortBusy(false)
    }
  }, [refreshState])

  // ---- prev / next --------------------------------------------------------------------
  let prev: (() => void) | null = null
  let next: (() => void) | null = null
  let nextLabel = 'Next'
  if (view?.kind === 'lesson0') {
    const first = learningOrder[0]
    if (first !== undefined) {
      next = () => openQuestion(first)
      nextLabel = `Start: Q${first}`
    }
  } else if (view?.kind === 'question') {
    const idx = order.indexOf(view.n)
    if (idx > 0) {
      const p = order[idx - 1]
      prev = () => openQuestion(p)
    } else if (idx === 0 && !inExam) {
      prev = openLesson0
    }
    if (idx >= 0 && idx < order.length - 1) {
      const nx = order[idx + 1]
      next = () => openQuestion(nx)
    } else if (idx === -1 && order.length > 0) {
      const first = order[0]
      next = () => openQuestion(first)
    }
  }

  // ---- keyboard shortcuts (captured before the terminal sees them) ---------------------
  const keys = useLatest({ doCheck, prev, next })
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!isAppShortcut(e)) return
      e.preventDefault()
      e.stopPropagation()
      if (e.key === 'Enter') void keys.current.doCheck()
      else if (e.key === 'ArrowLeft') keys.current.prev?.()
      else if (e.key === 'ArrowRight') keys.current.next?.()
    }
    window.addEventListener('keydown', onKey, true)
    return () => window.removeEventListener('keydown', onKey, true)
  }, [keys])

  // ---- splitter -----------------------------------------------------------------------
  const mainRef = useRef<HTMLElement>(null)
  const startDrag = (e: ReactMouseEvent) => {
    e.preventDefault()
    const main = mainRef.current
    if (!main) return
    document.body.classList.add('dragging')
    const onMove = (ev: MouseEvent) => {
      const rect = main.getBoundingClientRect()
      const pct = ((ev.clientX - rect.left) / rect.width) * 100
      setLeftPct(Math.round(Math.min(70, Math.max(25, pct)) * 10) / 10)
    }
    const onUp = () => {
      document.body.classList.remove('dragging')
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
  }

  // ---- render -------------------------------------------------------------------------
  const q = currentN !== null ? questions[currentN] ?? null : null
  const domain = q && course ? course.domains[q.domain] : undefined
  const examIndex = currentN !== null && inExam ? state!.examQuestions.indexOf(currentN) : -1
  const showHint = !!state && state.mode === 'learn' && state.passed.length === 0 && !hintDismissed

  return (
    <div className="app">
      <TopBar
        state={state}
        now={now}
        theme={theme}
        onToggleTheme={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
        onCourse={() => setDrawerOpen(true)}
        onStartExam={() => {
          setStartError(null)
          setStartOpen(true)
        }}
        onEndExam={() => {
          setEndError(null)
          setEndConfirm(true)
        }}
        onAbortExam={() => setAbortConfirm(true)}
        onHistory={() => setHistoryOpen(true)}
      />

      {stateError && (
        <div className="banner error">
          {stateError}
          <button type="button" className="btn tiny ghost" onClick={() => void refreshState()}>
            Retry
          </button>
        </div>
      )}
      {showHint && (
        <div className="banner hint">
          <span>
            <strong>New here?</strong> Start with Lesson 0, the Kubernetes &amp; kubectl fundamentals. Then read each
            question's <em>Lesson</em> tab before you solve it.
          </span>
          <button type="button" className="btn tiny primary" onClick={openLesson0}>
            Open Lesson 0
          </button>
          <button type="button" className="icon-btn" onClick={() => setHintDismissed(true)} aria-label="Dismiss">
            ✕
          </button>
        </div>
      )}

      <main className="main" ref={mainRef} style={{ '--left': `${leftPct}%` } as CSSProperties}>
        <div className="pane left">
          {view ? (
            <QuestionPanel
              mode={state?.mode ?? 'learn'}
              view={view}
              question={q}
              questionError={currentN !== null ? questionErrors[currentN] ?? null : null}
              domain={domain}
              weightPct={currentN !== null ? weightPct(currentN) : null}
              flagged={currentN !== null && flags.has(currentN)}
              onToggleFlag={inExam && currentN !== null ? () => void toggleFlag() : null}
              examIndex={examIndex >= 0 ? examIndex : null}
              examCount={state?.examQuestions.length ?? 0}
              tab={tab}
              onTab={setTab}
              lessonText={currentN !== null ? lessons[currentN] ?? null : null}
              lessonError={currentN !== null ? lessonErrors[currentN] ?? null : null}
              solutionText={currentN !== null ? solutions[currentN] ?? null : null}
              solutionError={currentN !== null ? solutionErrors[currentN] ?? null : null}
              solutionRevealed={currentN !== null && revealed.has(currentN)}
              onRevealSolution={() => currentN !== null && setRevealed((s) => new Set(s).add(currentN))}
              lesson0Text={lessons[0] ?? null}
              lesson0Error={lessonErrors[0] ?? null}
              check={currentN !== null ? checks[currentN] ?? null : null}
              checkError={currentN !== null ? checkErrors[currentN] || null : null}
              checking={checking !== null && checking === currentN}
              resetting={resetting !== null && resetting === currentN}
              resetMessage={currentN !== null ? resetMessages[currentN] ?? null : null}
              onCheck={() => void doCheck()}
              onReset={() => currentN !== null && setResetConfirm(currentN)}
              onPrev={prev}
              onNext={next}
              nextLabel={nextLabel}
              onOpenQuestion={openQuestion}
              onDismissCheck={() =>
                currentN !== null &&
                setChecks((m) => {
                  const { [currentN]: _drop, ...rest } = m
                  void _drop
                  return rest
                })
              }
            />
          ) : (
            <div className="placeholder center">{stateError ? 'Waiting for the server…' : 'Loading…'}</div>
          )}
        </div>
        <div className="splitter" onMouseDown={startDrag} role="separator" aria-orientation="vertical" title="Drag to resize" />
        <div className="pane right">
          <TerminalPanel />
        </div>
      </main>

      <CourseDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        mode={state?.mode ?? 'learn'}
        course={course}
        passed={passed}
        next={state?.next ?? null}
        examQuestions={state?.examQuestions ?? []}
        flags={flags}
        weightPct={weightPct}
        titles={titles}
        current={view ?? { kind: 'lesson0' }}
        onOpenQuestion={openQuestion}
        onOpenLesson0={openLesson0}
      />

      {startOpen && (
        <StartExamDialog busy={startBusy} error={startError} onStart={(k) => void startExam(k)} onCancel={() => setStartOpen(false)} />
      )}
      {endConfirm && (
        <ConfirmDialog
          title="End the exam?"
          message={
            <>
              <p>All exam questions will be graded now and you'll get your final score.</p>
              {endError && <div className="error-box">{endError}</div>}
            </>
          }
          confirmLabel="End and grade"
          busy={endBusy}
          busyLabel="Grading…"
          onConfirm={() => void endExam()}
          onCancel={() => setEndConfirm(false)}
        />
      )}
      {abortConfirm && (
        <ConfirmDialog
          title="Abort the exam?"
          message={<p>The exam stops without grading and nothing is saved to your history.</p>}
          confirmLabel="Abort exam"
          danger
          busy={abortBusy}
          onConfirm={() => void abortExam()}
          onCancel={() => setAbortConfirm(false)}
        />
      )}
      {resetConfirm !== null && (
        <ConfirmDialog
          title={`Reset Q${resetConfirm}?`}
          message={
            <p>
              This puts the question back to its starting state and <strong>deletes your work</strong> for it (resources
              in its namespace and its files in /opt/course/{resetConfirm}).
            </p>
          }
          confirmLabel="Reset question"
          danger
          onConfirm={() => void doReset(resetConfirm)}
          onCancel={() => setResetConfirm(null)}
        />
      )}
      {result && <ExamResultsModal result={result} onClose={() => setResult(null)} />}
      {historyOpen && <HistoryModal onClose={() => setHistoryOpen(false)} />}
      {toast && <div className="toast">{toast}</div>}
    </div>
  )
}
