package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*m`)

type Task struct {
	OK   bool   `json:"ok"`
	Text string `json:"text"`
}

type Score struct {
	N      int    `json:"n"`
	Title  string `json:"title"`
	Domain string `json:"domain"`
	Weight int    `json:"weight"`
	Pass   int    `json:"pass"`
	Total  int    `json:"total"`
	Tasks  []Task `json:"tasks"`
}

// Runner executes question scripts the same way the ckad CLI does.
type Runner struct {
	home    string
	logDir  string
	kubeDir string   // one kubeconfig per context, pinned to it (terminal/kubeconfig.sh)
	locks   sync.Map // per-question mutex: no check while a reset of the same question runs
}

func (r *Runner) lock(n int) *sync.Mutex {
	m, _ := r.locks.LoadOrStore(n, &sync.Mutex{})
	return m.(*sync.Mutex)
}

// script runs a question script in the question's own context, whatever context the
// candidate switched to. Without the pinned kubeconfigs it uses the candidate's, like before.
func (r *Runner) script(ctx context.Context, q *Question, name string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, "bash", filepath.Join(q.Dir, name))
	cmd.Env = append(os.Environ(), "CKAD_HOME="+r.home)
	if q.Context != "" {
		if kc := filepath.Join(r.kubeDir, q.Context); fileExists(kc) {
			cmd.Env = append(cmd.Env, "KUBECONFIG="+kc)
		}
	}
	cmd.Dir = "/root"
	return cmd
}

func fileExists(path string) bool {
	st, err := os.Stat(path)
	return err == nil && !st.IsDir()
}

// Check runs check.sh and parses its "✔ text" / "✘ text" lines and the final RESULT line.
func (r *Runner) Check(q *Question) (*Score, error) {
	l := r.lock(q.N)
	l.Lock()
	defer l.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	out, _ := r.script(ctx, q, "check.sh").Output() // non-zero exit still has useful output
	if ctx.Err() != nil {
		return nil, fmt.Errorf("check for question %d timed out", q.N)
	}
	s := &Score{N: q.N, Title: q.Title, Domain: q.Domain, Weight: q.Weight, Tasks: []Task{}}
	for _, line := range strings.Split(ansi.ReplaceAllString(string(out), ""), "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "✔"):
			s.Tasks = append(s.Tasks, Task{true, strings.TrimSpace(strings.TrimPrefix(line, "✔"))})
		case strings.HasPrefix(line, "✘"):
			s.Tasks = append(s.Tasks, Task{false, strings.TrimSpace(strings.TrimPrefix(line, "✘"))})
		case strings.HasPrefix(line, "RESULT "):
			f := strings.Fields(line)
			if len(f) == 3 {
				s.Pass, _ = strconv.Atoi(f[1])
				s.Total, _ = strconv.Atoi(f[2])
			}
		}
	}
	return s, nil
}

// Reset runs setup.sh, logging like the CLI to /tmp/ckad-logs/setup-N.log.
func (r *Runner) Reset(q *Question) (bool, string) {
	l := r.lock(q.N)
	l.Lock()
	defer l.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Minute)
	defer cancel()
	var buf bytes.Buffer
	cmd := r.script(ctx, q, "setup.sh")
	cmd.Stdout, cmd.Stderr = &buf, &buf
	err := cmd.Run()
	os.MkdirAll(r.logDir, 0o755)
	os.WriteFile(filepath.Join(r.logDir, fmt.Sprintf("setup-%d.log", q.N)), buf.Bytes(), 0o644)
	log := buf.String()
	if len(log) > 4000 {
		log = log[len(log)-4000:]
	}
	return err == nil, log
}

// parallel runs fn for each question with at most `limit` running at once.
func parallel(ns []int, limit int, fn func(int)) {
	sem := make(chan struct{}, limit)
	var wg sync.WaitGroup
	for _, n := range ns {
		wg.Add(1)
		sem <- struct{}{}
		go func(n int) {
			defer wg.Done()
			defer func() { <-sem }()
			fn(n)
		}(n)
	}
	wg.Wait()
}
