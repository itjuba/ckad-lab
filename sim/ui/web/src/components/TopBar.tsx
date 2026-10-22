import type { ReactNode } from 'react'
import type { State } from '../api'
import { formatDuration } from '../hooks'

interface Props {
  state: State | null
  now: number
  theme: 'dark' | 'light'
  onToggleTheme: () => void
  onCourse: () => void
  onStartExam: () => void
  onEndExam: () => void
  onAbortExam: () => void
  onHistory: () => void
}

export function TopBar({ state, now, theme, onToggleTheme, onCourse, onStartExam, onEndExam, onAbortExam, onHistory }: Props) {
  const inExam = state?.mode === 'exam'
  let timer: ReactNode = null
  if (inExam && state?.examStartedAt) {
    const left = state.examStartedAt + state.examSeconds - now
    const cls = left <= 0 ? 'timer over' : left < 600 ? 'timer red' : left < 1800 ? 'timer amber' : 'timer'
    timer = (
      <span className={cls} title="Time left in the mock exam">
        {left <= 0 ? 'Time is up' : formatDuration(left)}
      </span>
    )
  }

  return (
    <header className="topbar">
      <div className="brand">
        <span className="logo">k</span>
        <span className="brand-name">CKAD Lab</span>
      </div>
      {state && (
        <span className={inExam ? 'mode-badge exam' : 'mode-badge'}>{inExam ? 'Exam' : 'Practice'}</span>
      )}
      {timer}
      {state && !inExam && (
        <span className="progress" title="Questions passed in practice mode">
          <span className="progress-bar">
            <span style={{ width: `${(state.passed.length / Math.max(1, state.total)) * 100}%` }} />
          </span>
          {state.passed.length}/{state.total} passed
        </span>
      )}
      <span className="spacer" />
      <button type="button" className="btn ghost" onClick={onCourse}>
        {inExam ? 'Questions' : 'Course'}
      </button>
      {state && !inExam && (
        <button type="button" className="btn ghost" onClick={onStartExam}>
          Start exam
        </button>
      )}
      {inExam && (
        <>
          <button type="button" className="btn primary" onClick={onEndExam}>
            End exam
          </button>
          <button type="button" className="btn tiny ghost" onClick={onAbortExam} title="Stop without grading">
            Abort
          </button>
        </>
      )}
      <button type="button" className="btn ghost" onClick={onHistory}>
        History
      </button>
      <button
        type="button"
        className="icon-btn"
        onClick={onToggleTheme}
        title={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'}
        aria-label="Toggle theme"
      >
        {theme === 'dark' ? '☀' : '☾'}
      </button>
    </header>
  )
}
