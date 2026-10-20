package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

type App struct {
	home   string
	state  *State
	runner *Runner
	examMu sync.Mutex // one exam start/end at a time
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, status int, format string, args ...any) {
	writeJSON(w, status, map[string]string{"error": fmt.Sprintf(format, args...)})
}

func (a *App) course(w http.ResponseWriter) (*Course, bool) {
	c, err := loadCourse(a.home)
	if err != nil {
		fail(w, http.StatusInternalServerError, "can't read questions: %v", err)
		return nil, false
	}
	return c, true
}

// questionFromPath resolves {n} and the course in one go.
func (a *App) questionFromPath(w http.ResponseWriter, r *http.Request) (*Course, *Question, bool) {
	c, ok := a.course(w)
	if !ok {
		return nil, nil, false
	}
	n, err := strconv.Atoi(r.PathValue("n"))
	if err != nil {
		fail(w, http.StatusBadRequest, "bad question number")
		return nil, nil, false
	}
	q, err := c.question(n)
	if err != nil {
		fail(w, http.StatusNotFound, "%v", err)
		return nil, nil, false
	}
	return c, q, true
}

func (a *App) blockedInExam(w http.ResponseWriter, what string) bool {
	if a.state.InExam() {
		fail(w, http.StatusForbidden, "Exam mode: no %s until the end, like the real exam", what)
		return true
	}
	return false
}

func (a *App) stateJSON(c *Course) map[string]any {
	passed := a.state.Passed()
	if passed == nil {
		passed = []int{}
	}
	exam := a.state.ExamQuestions()
	if exam == nil {
		exam = []int{}
	}
	return map[string]any{
		"mode":          a.state.Mode(),
		"examStartedAt": a.state.ExamStartedAt(),
		"examSeconds":   examSeconds,
		"examQuestions": exam,
		"passed":        passed,
		"next":          a.state.Next(c),
		"total":         len(c.Questions),
	}
}

func (a *App) handleState(w http.ResponseWriter, r *http.Request) {
	if c, ok := a.course(w); ok {
		writeJSON(w, http.StatusOK, a.stateJSON(c))
	}
}

func (a *App) handleCourse(w http.ResponseWriter, r *http.Request) {
	c, ok := a.course(w)
	if !ok {
		return
	}
	type item struct {
		N      int    `json:"n"`
		Title  string `json:"title"`
		Lesson string `json:"lesson"`
		Domain string `json:"domain"`
		Passed bool   `json:"passed"`
	}
	type section struct {
		Title     string `json:"title"`
		Questions []item `json:"questions"`
	}
	sections := []section{}
	for _, s := range c.Sections {
		sec := section{Title: s.Title, Questions: []item{}}
		for _, n := range s.Questions {
			q := c.Questions[n]
			sec.Questions = append(sec.Questions, item{n, q.Title, q.Lesson, q.Domain, a.state.IsPassed(n)})
		}
		sections = append(sections, sec)
	}
	lesson0 := strings.TrimSpace(strings.TrimPrefix(firstLine(filepath.Join(a.home, "course", "00-fundamentals.md")), "#"))
	if i := strings.Index(lesson0, ":"); i >= 0 {
		lesson0 = strings.TrimSpace(lesson0[i+1:])
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"lesson0":  map[string]string{"title": lesson0},
		"sections": sections,
		"domains":  domains,
	})
}

func (a *App) handleQuestion(w http.ResponseWriter, r *http.Request) {
	c, q, ok := a.questionFromPath(w, r)
	if !ok {
		return
	}
	md, err := os.ReadFile(filepath.Join(q.Dir, "question.md"))
	if err != nil {
		fail(w, http.StatusInternalServerError, "can't read question: %v", err)
		return
	}
	var step any
	if s, found := c.step(q.N); found {
		step = s
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"n": q.N, "title": q.Title, "domain": q.Domain,
		"step": step, "steps": len(c.Path), "markdown": string(md),
	})
}

func (a *App) serveMarkdown(w http.ResponseWriter, path, what string) {
	if a.blockedInExam(w, what) {
		return
	}
	md, err := os.ReadFile(path)
	if err != nil {
		fail(w, http.StatusNotFound, "no %s for this question yet", what)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"markdown": string(md)})
}

func (a *App) handleLesson0(w http.ResponseWriter, r *http.Request) {
	a.serveMarkdown(w, filepath.Join(a.home, "course", "00-fundamentals.md"), "lessons")
}

func (a *App) handleLesson(w http.ResponseWriter, r *http.Request) {
	if _, q, ok := a.questionFromPath(w, r); ok {
		a.serveMarkdown(w, filepath.Join(q.Dir, "explain.md"), "lessons")
	}
}

func (a *App) handleSolution(w http.ResponseWriter, r *http.Request) {
	if _, q, ok := a.questionFromPath(w, r); ok {
		a.serveMarkdown(w, filepath.Join(q.Dir, "solution.md"), "solutions")
	}
}

func (a *App) handleCheck(w http.ResponseWriter, r *http.Request) {
	c, q, ok := a.questionFromPath(w, r)
	if !ok || a.blockedInExam(w, "grading") {
		return
	}
	s, err := a.runner.Check(q)
	if err != nil {
		fail(w, http.StatusInternalServerError, "%v", err)
		return
	}
	full := s.Total > 0 && s.Pass == s.Total
	if full {
		a.state.MarkPassed(q.N)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"n": q.N, "tasks": s.Tasks, "pass": s.Pass, "total": s.Total,
		"passed": full, "next": a.state.Next(c),
	})
}

func (a *App) handleReset(w http.ResponseWriter, r *http.Request) {
	if _, q, ok := a.questionFromPath(w, r); ok {
		okRun, log := a.runner.Reset(q)
		writeJSON(w, http.StatusOK, map[string]any{"ok": okRun, "log": log})
	}
}

// --- exam ---------------------------------------------------------------------------

func (a *App) handleExamStart(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Keep bool `json:"keep"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if !a.examMu.TryLock() {
		fail(w, http.StatusConflict, "an exam is already being started or graded")
		return
	}
	defer a.examMu.Unlock()
	if a.state.InExam() {
		fail(w, http.StatusConflict, "an exam is already running; end it first")
		return
	}
	c, ok := a.course(w)
	if !ok {
		return
	}
	var picked []int
	for _, d := range domainOrder {
		var pool []int
		for _, n := range c.ids() {
			if c.Questions[n].Domain == d {
				pool = append(pool, n)
			}
		}
		rand.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })
		if len(pool) > examPick[d] {
			pool = pool[:examPick[d]]
		}
		picked = append(picked, pool...)
	}
	rand.Shuffle(len(picked), func(i, j int) { picked[i], picked[j] = picked[j], picked[i] })

	if !body.Keep {
		var mu sync.Mutex
		var failed []string
		parallel(picked, 6, func(n int) {
			if ok, _ := a.runner.Reset(c.Questions[n]); !ok {
				mu.Lock()
				failed = append(failed, strconv.Itoa(n))
				mu.Unlock()
			}
		})
		if len(failed) > 0 {
			fail(w, http.StatusInternalServerError, "setup failed for question(s) %s; see /tmp/ckad-logs", strings.Join(failed, ", "))
			return
		}
	}
	if err := a.state.StartExam(picked); err != nil {
		fail(w, http.StatusInternalServerError, "can't save exam state: %v", err)
		return
	}
	writeJSON(w, http.StatusOK, a.stateJSON(c))
}

type domainResult struct {
	Code    string `json:"code"`
	Name    string `json:"name"`
	Short   string `json:"short"`
	Weight  int    `json:"weight"`
	Pass    int    `json:"pass"`
	Total   int    `json:"total"`
	Percent int    `json:"percent"`
}

func (a *App) handleExamEnd(w http.ResponseWriter, r *http.Request) {
	if !a.examMu.TryLock() {
		fail(w, http.StatusConflict, "the exam is already being graded")
		return
	}
	defer a.examMu.Unlock()
	if !a.state.InExam() {
		fail(w, http.StatusConflict, "no exam running")
		return
	}
	c, ok := a.course(w)
	if !ok {
		return
	}
	ids := a.state.ExamQuestions()
	var used int64
	if start := a.state.ExamStartedAt(); start != nil {
		used = time.Now().Unix() - *start
	}

	results := make(map[int]*Score)
	var mu sync.Mutex
	parallel(ids, 6, func(n int) {
		q := c.Questions[n]
		if q == nil {
			return
		}
		s, err := a.runner.Check(q)
		if err != nil {
			s = &Score{N: n, Title: q.Title, Domain: q.Domain, Tasks: []Task{}}
		}
		mu.Lock()
		results[n] = s
		mu.Unlock()
	})

	// Same weighting as the CLI: each domain's task ratio times its exam weight.
	var doms []domainResult
	weighted, wsum := 0, 0
	for _, d := range domainOrder {
		dr := domainResult{Code: d, Name: domains[d].Name, Short: domains[d].Short, Weight: domains[d].Weight}
		for _, n := range ids {
			if s := results[n]; s != nil && s.Domain == d {
				dr.Pass += s.Pass
				dr.Total += s.Total
			}
		}
		if dr.Total == 0 {
			continue
		}
		dr.Percent = dr.Pass * 100 / dr.Total
		weighted += dr.Weight * dr.Pass * 1000 / dr.Total
		wsum += dr.Weight
		doms = append(doms, dr)
	}
	score := 0
	if wsum > 0 {
		score = weighted / wsum / 10
	}
	questions := []*Score{}
	for _, n := range ids {
		if s := results[n]; s != nil {
			questions = append(questions, s)
		}
	}

	parts := make([]string, len(ids))
	for i, n := range ids {
		parts[i] = strconv.Itoa(n)
	}
	a.state.AppendHistory(fmt.Sprintf("%s  %d%%  time used %s  questions: %s ",
		time.Now().Format("2006-01-02 15:04"), score, fmtDuration(used), strings.Join(parts, " ")))
	a.state.StopExam()

	writeJSON(w, http.StatusOK, map[string]any{
		"score": score, "passedExam": score >= 66, "passMark": 66, "timeUsed": used,
		"domains": doms, "questions": questions,
	})
}

func (a *App) handleExamAbort(w http.ResponseWriter, r *http.Request) {
	a.state.StopExam()
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

var historyLine = regexp.MustCompile(`^(\S+ \S+)\s+(\d+)%\s+time used (\S+)(?:\s+questions:\s*(.*))?$`)

func (a *App) handleExamHistory(w http.ResponseWriter, r *http.Request) {
	type entry struct {
		Date      string `json:"date"`
		Score     int    `json:"score"`
		TimeUsed  string `json:"timeUsed"`
		Questions []int  `json:"questions"`
	}
	entries := []entry{}
	if f, err := os.Open(a.state.path("exam-history")); err == nil {
		defer f.Close()
		s := bufio.NewScanner(f)
		for s.Scan() {
			m := historyLine.FindStringSubmatch(strings.TrimSpace(s.Text()))
			if m == nil {
				continue
			}
			score, _ := strconv.Atoi(m[2])
			qs := ints(m[4])
			if qs == nil {
				qs = []int{}
			}
			entries = append(entries, entry{m[1], score, m[3], qs})
		}
	}
	for i, j := 0, len(entries)-1; i < j; i, j = i+1, j-1 { // newest first
		entries[i], entries[j] = entries[j], entries[i]
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
}
