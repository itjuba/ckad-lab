package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const examSeconds = 7200

// State is the progress/exam state shared with the ckad CLI (files in /opt/course/.ckad).
type State struct {
	dir string
	mu  sync.Mutex
}

func (s *State) path(name string) string { return filepath.Join(s.dir, name) }

func (s *State) read(name string) string {
	b, err := os.ReadFile(s.path(name))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func (s *State) write(name, content string) error {
	if err := os.MkdirAll(s.dir, 0o755); err != nil {
		return err
	}
	return os.WriteFile(s.path(name), []byte(content), 0o644)
}

func (s *State) remove(names ...string) {
	for _, n := range names {
		os.Remove(s.path(n))
	}
}

func ints(text string) []int {
	var out []int
	for _, f := range strings.Fields(text) {
		if n, err := strconv.Atoi(f); err == nil {
			out = append(out, n)
		}
	}
	return out
}

func (s *State) Mode() string {
	if s.read("mode") == "exam" {
		return "exam"
	}
	return "learn"
}

func (s *State) InExam() bool { return s.Mode() == "exam" }

func (s *State) ExamStartedAt() *int64 {
	v, err := strconv.ParseInt(s.read("exam-start"), 10, 64)
	if err != nil {
		return nil
	}
	return &v
}

func (s *State) ExamQuestions() []int { return ints(s.read("exam-questions")) }

func (s *State) Passed() []int { return ints(s.read("passed")) }

func (s *State) IsPassed(n int) bool {
	for _, p := range s.Passed() {
		if p == n {
			return true
		}
	}
	return false
}

func (s *State) MarkPassed(n int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.IsPassed(n) {
		return nil
	}
	f, err := os.OpenFile(s.path("passed"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(strconv.Itoa(n) + "\n")
	return err
}

func (s *State) Next(c *Course) *int {
	for _, n := range c.Path {
		if !s.IsPassed(n) {
			n := n
			return &n
		}
	}
	return nil
}

func (s *State) StartExam(questions []int) error {
	parts := make([]string, len(questions))
	for i, n := range questions {
		parts[i] = strconv.Itoa(n)
	}
	if err := s.write("exam-questions", strings.Join(parts, "\n")+"\n"); err != nil {
		return err
	}
	s.remove("exam-flags")
	if err := s.write("mode", "exam\n"); err != nil {
		return err
	}
	return s.write("exam-start", strconv.FormatInt(time.Now().Unix(), 10)+"\n")
}

func (s *State) StopExam() { s.remove("mode", "exam-start", "exam-questions", "exam-flags") }

// Flags are the exam questions marked for review (same file as `ckad flag`).
func (s *State) Flags() []int { return ints(s.read("exam-flags")) }

func (s *State) SetFlag(n int, on bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	var kept []string
	for _, f := range s.Flags() {
		if f != n {
			kept = append(kept, strconv.Itoa(f))
		}
	}
	if on {
		kept = append(kept, strconv.Itoa(n))
	}
	if len(kept) == 0 {
		s.remove("exam-flags")
		return nil
	}
	return s.write("exam-flags", strings.Join(kept, "\n")+"\n")
}

func (s *State) AppendHistory(line string) error {
	f, err := os.OpenFile(s.path("exam-history"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(line + "\n")
	return err
}

func fmtDuration(seconds int64) string {
	if seconds < 0 {
		seconds = 0
	}
	return strconv.FormatInt(seconds/3600, 10) + ":" + pad2(seconds%3600/60) + ":" + pad2(seconds%60)
}

func pad2(v int64) string {
	if v < 10 {
		return "0" + strconv.FormatInt(v, 10)
	}
	return strconv.FormatInt(v, 10)
}
