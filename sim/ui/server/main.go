// ckad-ui: the CKAD Lab web interface. Serves the React app and an API over the same
// question files and progress state as the `ckad` CLI, plus a browser terminal.
// It runs inside the ckad-terminal container; see ../API.md.
package main

import (
	"embed"
	"io/fs"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

//go:embed all:web
var webFiles embed.FS

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// allowedHosts guards against DNS rebinding: only these Host headers are served.
var allowedHosts = map[string]bool{}

func hostAllowed(r *http.Request) bool {
	host := r.Host
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	return allowedHosts[strings.ToLower(host)]
}

// sameOrigin: requests from a browser page must come from this server's own origin.
// Requests without an Origin header (curl, the CLI) are fine.
func sameOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return true
	}
	u, err := url.Parse(origin)
	return err == nil && strings.EqualFold(u.Host, r.Host)
}

func guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !hostAllowed(r) {
			http.Error(w, "host not allowed", http.StatusForbidden)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead && !sameOrigin(r) {
			http.Error(w, "cross-origin request refused", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// spa serves the built React app and falls back to index.html for client-side routes.
func spa() http.Handler {
	sub, err := fs.Sub(webFiles, "web")
	if err != nil {
		log.Fatal(err)
	}
	files := http.FileServer(http.FS(sub))
	if _, err := fs.Stat(sub, "index.html"); err != nil {
		// Built without the React app (plain `go build`): say so instead of listing files.
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write([]byte(`<h1>CKAD Lab</h1><p>This ckad-ui binary was built without the web app.
Build sim/ui/web and copy dist/ into sim/ui/server/web/, or run <code>.\sim.ps1 update</code>.
The API is under <code>/api/</code>.</p>`))
		})
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/")
		if path != "" {
			if _, err := fs.Stat(sub, path); err != nil {
				r = r.Clone(r.Context())
				r.URL.Path = "/"
			}
		}
		if r.URL.Path == "/" {
			w.Header().Set("Cache-Control", "no-cache")
		}
		files.ServeHTTP(w, r)
	})
}

func main() {
	home := env("CKAD_HOME", "/ckad")
	addr := env("CKAD_UI_ADDR", ":8090")
	for _, h := range strings.Split(env("CKAD_UI_HOSTS", "localhost,127.0.0.1,::1"), ",") {
		allowedHosts[strings.ToLower(strings.Trim(strings.TrimSpace(h), "[]"))] = true
	}

	app := &App{
		home:   home,
		state:  &State{dir: env("CKAD_STATE", "/opt/course/.ckad")},
		runner: &Runner{home: home, logDir: "/tmp/ckad-logs", kubeDir: env("CKAD_KUBE_DIR", "/run/ckad/kube")},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/state", app.handleState)
	mux.HandleFunc("GET /api/course", app.handleCourse)
	mux.HandleFunc("GET /api/lessons/0", app.handleLesson0)
	mux.HandleFunc("GET /api/questions/{n}", app.handleQuestion)
	mux.HandleFunc("GET /api/questions/{n}/lesson", app.handleLesson)
	mux.HandleFunc("GET /api/questions/{n}/solution", app.handleSolution)
	mux.HandleFunc("POST /api/questions/{n}/check", app.handleCheck)
	mux.HandleFunc("POST /api/questions/{n}/reset", app.handleReset)
	mux.HandleFunc("POST /api/questions/{n}/flag", app.handleFlag)
	mux.HandleFunc("POST /api/exam/start", app.handleExamStart)
	mux.HandleFunc("POST /api/exam/end", app.handleExamEnd)
	mux.HandleFunc("POST /api/exam/abort", app.handleExamAbort)
	mux.HandleFunc("GET /api/exam/history", app.handleExamHistory)
	mux.HandleFunc("GET /api/terminal", app.handleTerminal)
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		fail(w, http.StatusNotFound, "unknown API endpoint")
	})
	mux.Handle("/", spa())

	srv := &http.Server{
		Addr:              addr,
		Handler:           guard(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("ckad-ui listening on %s (questions in %s)", addr, home)
	log.Fatal(srv.ListenAndServe())
}
