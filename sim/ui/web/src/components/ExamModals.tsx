import { useEffect, useState } from 'react'
import { api, errorMessage, type ExamResult, type HistoryEntry } from '../api'
import { formatDuration } from '../hooks'
import { Modal, Spinner } from './Modal'

interface StartProps {
  busy: boolean
  error: string | null
  onStart: (keep: boolean) => void
  onCancel: () => void
}

export function StartExamDialog({ busy, error, onStart, onCancel }: StartProps) {
  const [keep, setKeep] = useState(false)
  return (
    <Modal
      title="Start a mock exam"
      onClose={onCancel}
      busy={busy}
      footer={
        <>
          <button type="button" className="btn ghost" onClick={onCancel} disabled={busy}>
            Cancel
          </button>
          <button type="button" className="btn primary" onClick={() => onStart(keep)} disabled={busy}>
            {busy ? (
              <>
                <Spinner /> Setting up the exam…
              </>
            ) : (
              'Start the 2-hour exam'
            )}
          </button>
        </>
      }
    >
      <ul className="plain-list">
        <li>
          <strong>18 random questions</strong>, spread across the domains like the real exam.
        </li>
        <li>
          <strong>2 hours</strong>. The timer shows in the top bar.
        </li>
        <li>
          <strong>No grading, lessons or solutions</strong> until you end the exam, like the real thing.
        </li>
        <li>The picked questions are reset first, which deletes your work on them.</li>
      </ul>
      <label className="checkbox">
        <input type="checkbox" checked={keep} onChange={(e) => setKeep(e.target.checked)} disabled={busy} />
        Keep the current state of the questions (don't reset them)
      </label>
      {busy && <p className="muted">Resetting the questions can take up to two minutes.</p>}
      {error && <div className="error-box">{error}</div>}
    </Modal>
  )
}

export function ExamResultsModal({ result, onClose }: { result: ExamResult; onClose: () => void }) {
  const [open, setOpen] = useState<number | null>(null)
  return (
    <Modal
      title="Mock exam results"
      onClose={onClose}
      wide
      footer={
        <button type="button" className="btn primary" onClick={onClose}>
          Back to learning mode
        </button>
      }
    >
      <div className="score-hero">
        <div className={result.passedExam ? 'score pass' : 'score fail'}>{result.score}%</div>
        <div>
          <div className={result.passedExam ? 'verdict pass' : 'verdict fail'}>
            {result.passedExam ? 'PASS' : 'NOT YET'}
          </div>
          <div className="muted">
            Pass mark {result.passMark}% · time used {formatDuration(result.timeUsed)}
          </div>
        </div>
      </div>

      <h3>By domain</h3>
      <table className="table">
        <thead>
          <tr>
            <th>Domain</th>
            <th className="num">Weight</th>
            <th className="num">Tasks</th>
            <th className="num">Score</th>
          </tr>
        </thead>
        <tbody>
          {result.domains.map((d) => (
            <tr key={d.code}>
              <td title={d.name}>{d.short}</td>
              <td className="num">{d.weight}%</td>
              <td className="num">
                {d.pass}/{d.total}
              </td>
              <td className="num">
                <span className={d.percent >= result.passMark ? 'good' : 'bad'}>{d.percent}%</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>By question</h3>
      <ul className="result-questions">
        {result.questions.map((q) => {
          const full = q.total > 0 && q.pass === q.total
          return (
            <li key={q.n}>
              <button type="button" className="result-q" onClick={() => setOpen(open === q.n ? null : q.n)}>
                <span className={full ? 'mark good' : 'mark bad'}>{full ? '✔' : '✘'}</span>
                <span className="grow">
                  Q{q.n} {q.title}
                </span>
                <span className="num">
                  {q.pass}/{q.total}
                </span>
                <span className="muted">{open === q.n ? '▴' : '▾'}</span>
              </button>
              {open === q.n && (
                <ul className="tasks nested">
                  {q.tasks.map((t, i) => (
                    <li key={i} className={t.ok ? 'task ok' : 'task ko'}>
                      <span className="mark">{t.ok ? '✔' : '✘'}</span>
                      <span>{t.text}</span>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          )
        })}
      </ul>
      <p className="muted">Solutions and lessons are unlocked again in learning mode.</p>
    </Modal>
  )
}

export function HistoryModal({ onClose }: { onClose: () => void }) {
  const [entries, setEntries] = useState<HistoryEntry[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  useEffect(() => {
    api
      .examHistory()
      .then((r) => setEntries(r.entries ?? []))
      .catch((e) => setError(errorMessage(e)))
  }, [])
  return (
    <Modal title="Exam history" onClose={onClose}>
      {error && <div className="error-box">{error}</div>}
      {!error && entries === null && (
        <p className="muted">
          <Spinner /> Loading…
        </p>
      )}
      {entries && entries.length === 0 && <p className="muted">No mock exams taken yet. Start one from the top bar.</p>}
      {entries && entries.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Date</th>
              <th className="num">Score</th>
              <th className="num">Time used</th>
              <th className="num">Questions</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e, i) => (
              <tr key={i}>
                <td>{e.date}</td>
                <td className="num">
                  <span className={e.score >= 66 ? 'good' : 'bad'}>{e.score}%</span>
                </td>
                <td className="num">{e.timeUsed}</td>
                <td className="num" title={e.questions.map((n) => `Q${n}`).join(', ')}>
                  {e.questions.length}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Modal>
  )
}
