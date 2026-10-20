package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Domain is one CKAD curriculum domain (CKAD_Curriculum_v1.37) with its exam weight.
type Domain struct {
	Name   string `json:"name"`
	Short  string `json:"short"`
	Weight int    `json:"weight"`
}

var domainOrder = []string{"D1", "D2", "D3", "D4", "D5"}

var domains = map[string]Domain{
	"D1": {"Application Design and Build", "Design & Build", 20},
	"D2": {"Application Deployment", "Deployment", 20},
	"D3": {"Application Observability and Maintenance", "Observability", 15},
	"D4": {"Application Environment, Configuration and Security", "Config & Security", 25},
	"D5": {"Services and Networking", "Networking", 20},
}

// Mock exam composition, same as the CLI: 18 questions spread like the exam's weights.
var examPick = map[string]int{"D1": 4, "D2": 4, "D3": 3, "D4": 4, "D5": 3}

// Question is the static description of one question folder.
type Question struct {
	N      int
	Title  string
	Lesson string
	Domain string
	Dir    string
}

type Section struct {
	Title     string
	Questions []int
}

// Course is everything read from disk: questions and the learning path.
type Course struct {
	Questions map[int]*Question
	Sections  []Section
	Path      []int // learning order (only existing questions)
}

var questionDir = regexp.MustCompile(`^q(\d+)$`)

func firstLine(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	if s.Scan() {
		return strings.TrimSpace(s.Text())
	}
	return ""
}

func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// loadCourse reads the question folders and the learning path. It is cheap, so the API
// reloads it per request and edits on disk show up immediately.
func loadCourse(home string) (*Course, error) {
	entries, err := os.ReadDir(filepath.Join(home, "questions"))
	if err != nil {
		return nil, err
	}
	c := &Course{Questions: map[int]*Question{}}
	for _, e := range entries {
		m := questionDir.FindStringSubmatch(e.Name())
		if !e.IsDir() || m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		dir := filepath.Join(home, "questions", e.Name())
		q := &Question{
			N:      n,
			Dir:    dir,
			Title:  strings.TrimSpace(strings.TrimPrefix(firstLine(filepath.Join(dir, "question.md")), "#")),
			Domain: readTrim(filepath.Join(dir, "domain")),
		}
		if l := firstLine(filepath.Join(dir, "explain.md")); l != "" {
			l = strings.TrimSpace(strings.TrimPrefix(l, "#"))
			if i := strings.Index(l, ":"); i >= 0 && strings.HasPrefix(l, "Lesson") {
				l = strings.TrimSpace(l[i+1:])
			}
			q.Lesson = l
		}
		c.Questions[n] = q
	}

	f, err := os.Open(filepath.Join(home, "learning-path"))
	if err == nil {
		defer f.Close()
		s := bufio.NewScanner(f)
		seen := map[int]bool{}
		for s.Scan() {
			line := strings.TrimSpace(s.Text())
			switch {
			case strings.HasPrefix(line, "## "):
				c.Sections = append(c.Sections, Section{Title: strings.TrimPrefix(line, "## ")})
			case line == "" || strings.HasPrefix(line, "#"):
			default:
				n, err := strconv.Atoi(line)
				if err != nil || c.Questions[n] == nil || seen[n] {
					continue
				}
				seen[n] = true
				if len(c.Sections) == 0 {
					c.Sections = append(c.Sections, Section{Title: "Questions"})
				}
				last := &c.Sections[len(c.Sections)-1]
				last.Questions = append(last.Questions, n)
				c.Path = append(c.Path, n)
			}
		}
		// Questions missing from the path still need a home.
		var rest []int
		for n := range c.Questions {
			if !seen[n] {
				rest = append(rest, n)
			}
		}
		if len(rest) > 0 {
			sort.Ints(rest)
			c.Sections = append(c.Sections, Section{Title: "More questions", Questions: rest})
			c.Path = append(c.Path, rest...)
		}
	}
	return c, nil
}

func (c *Course) ids() []int {
	ids := make([]int, 0, len(c.Questions))
	for n := range c.Questions {
		ids = append(ids, n)
	}
	sort.Ints(ids)
	return ids
}

func (c *Course) step(n int) (int, bool) {
	for i, p := range c.Path {
		if p == n {
			return i + 1, true
		}
	}
	return 0, false
}

func (c *Course) question(n int) (*Question, error) {
	q := c.Questions[n]
	if q == nil {
		return nil, fmt.Errorf("no such question: %d", n)
	}
	return q, nil
}
