package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"syscall"

	"github.com/creack/pty"
	"github.com/gorilla/websocket"
)

type termMessage struct {
	Type string `json:"type"`
	Data string `json:"data"`
	Cols uint16 `json:"cols"`
	Rows uint16 `json:"rows"`
}

func (a *App) upgrader() *websocket.Upgrader {
	return &websocket.Upgrader{
		ReadBufferSize:  4096,
		WriteBufferSize: 32 * 1024,
		// Browsers don't apply CORS to WebSockets, so only same-origin pages may connect;
		// otherwise any website could open a shell in this container.
		CheckOrigin: func(r *http.Request) bool { return sameOrigin(r) },
	}
}

// handleTerminal gives each WebSocket its own interactive bash on a pseudo-terminal.
func (a *App) handleTerminal(w http.ResponseWriter, r *http.Request) {
	conn, err := a.upgrader().Upgrade(w, r, nil)
	if err != nil {
		return // Upgrade already wrote the error response
	}
	defer conn.Close()

	cmd := exec.Command("bash")
	cmd.Dir = "/root"
	cmd.Env = append(os.Environ(), "TERM=xterm-256color", "HOME=/root", "LANG=C.UTF-8", "CKAD_HOME="+a.home)
	ptmx, err := pty.StartWithSize(cmd, &pty.Winsize{Cols: 120, Rows: 32})
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte("failed to start shell: "+err.Error()))
		return
	}
	defer func() {
		ptmx.Close()
		// pty.Start makes bash a session leader: kill its whole process group.
		syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		cmd.Wait()
	}()

	var writeMu sync.Mutex
	done := make(chan struct{})

	// shell -> browser
	go func() {
		defer close(done)
		buf := make([]byte, 32*1024)
		for {
			n, err := ptmx.Read(buf)
			if n > 0 {
				writeMu.Lock()
				werr := conn.WriteMessage(websocket.BinaryMessage, buf[:n])
				writeMu.Unlock()
				if werr != nil {
					return
				}
			}
			if err != nil {
				return // shell exited
			}
		}
	}()

	// browser -> shell
	go func() {
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				ptmx.Close()
				return
			}
			var m termMessage
			if json.Unmarshal(data, &m) != nil {
				continue
			}
			switch m.Type {
			case "input":
				ptmx.Write([]byte(m.Data))
			case "resize":
				if m.Cols > 0 && m.Rows > 0 {
					pty.Setsize(ptmx, &pty.Winsize{Cols: m.Cols, Rows: m.Rows})
				}
			}
		}
	}()

	<-done
	writeMu.Lock()
	conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "shell exited"))
	writeMu.Unlock()
	log.Printf("terminal session closed")
}
