// devvm-mux carries every TCP connection for one smol port-forward over a
// single `smolvm machine exec` session, multiplexed with yamux.
//
// smol guests have no host-routable network: the only host<->guest channel is
// `machine exec`'s stdio. Opening one exec per connection (the old socat
// bridge) hit smolvm's poor concurrency across separate exec sessions, so a
// browser's parallel requests wedged. Instead we keep ONE exec alive for the
// life of the forward and multiplex all connections over it:
//
//	host:                                            guest:
//	  listen 127.0.0.1:H  --\                    /-- serve
//	   accept -> yamux Open ==== one exec pipe ==== yamux Accept -> dial 127.0.0.1:G
//	  (yamux client)          (single stdio)        (yamux server)
//
// The host side spawns and owns the exec child (everything after `--`), so the
// whole forward is one process tree that devvm can start, reap, and status via
// a single PID.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"syscall"

	"github.com/hashicorp/yamux"
)

func main() {
	log.SetFlags(0)
	log.SetPrefix("devvm-mux: ")
	if len(os.Args) < 2 {
		usage()
	}
	switch os.Args[1] {
	case "listen":
		runListen(os.Args[2:])
	case "serve":
		runServe(os.Args[2:])
	default:
		usage()
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `usage:
  devvm-mux listen --addr HOST:PORT -- CMD [ARGS...]
        Host side. Listen on HOST:PORT and carry every accepted connection,
        multiplexed, over CMD's stdio (CMD is the `+"`smolvm machine exec`"+`
        that runs `+"`devvm-mux serve`"+` in the guest). Exits non-zero if the
        address is already bound, so the caller can try another port.

  devvm-mux serve --target HOST:PORT
        Guest side. Read the multiplexed stream from stdin/stdout and forward
        each stream to HOST:PORT inside the guest.
`)
	os.Exit(2)
}

// muxConfig tunes yamux for a forward carried over an exec pipe. Keepalives let
// either end notice a dead peer (e.g. the VM stopped) instead of hanging.
func muxConfig() *yamux.Config {
	c := yamux.DefaultConfig()
	c.EnableKeepAlive = true
	c.LogOutput = os.Stderr
	return c
}

// stdio adapts a separate reader/writer pair into the single ReadWriteCloser
// yamux wants. Closing is a no-op: the session is torn down by ending the exec
// (host kills the child; guest reaches stdin EOF), not by closing these fds.
type stdio struct {
	in  io.Reader
	out io.Writer
}

func (s stdio) Read(p []byte) (int, error)  { return s.in.Read(p) }
func (s stdio) Write(p []byte) (int, error) { return s.out.Write(p) }
func (stdio) Close() error                  { return nil }

// splice copies both directions between two connections and returns once either
// side closes, then closes both so the other copy unblocks. yamux streams and
// TCP conns both satisfy net.Conn.
func splice(a, b net.Conn) {
	done := make(chan struct{}, 2)
	go func() { io.Copy(a, b); done <- struct{}{} }()
	go func() { io.Copy(b, a); done <- struct{}{} }()
	<-done
	a.Close()
	b.Close()
	<-done
}

// --- host side -------------------------------------------------------------

func runListen(args []string) {
	fs := flag.NewFlagSet("listen", flag.ExitOnError)
	addr := fs.String("addr", "127.0.0.1:0", "host loopback address to listen on")
	_ = fs.Parse(args)
	cmd := fs.Args()
	if len(cmd) == 0 {
		log.Fatal("listen: expected the transport command after `--`")
	}

	// Bind first: a busy port must fail fast (non-zero) so devvm can bump.
	ln, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatalf("listen %s: %v", *addr, err)
	}
	defer ln.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Own the exec child in its own process group so we can take down smolvm
	// and everything it spawned with a single group kill.
	child := exec.CommandContext(ctx, cmd[0], cmd[1:]...)
	child.Stderr = os.Stderr
	child.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	in, err := child.StdinPipe()
	if err != nil {
		log.Fatalf("stdin pipe: %v", err)
	}
	out, err := child.StdoutPipe()
	if err != nil {
		log.Fatalf("stdout pipe: %v", err)
	}
	if err := child.Start(); err != nil {
		log.Fatalf("spawn transport: %v", err)
	}
	defer killGroup(child)

	session, err := yamux.Client(stdio{in: out, out: in}, muxConfig())
	if err != nil {
		log.Fatalf("yamux client: %v", err)
	}

	// Stop accepting once the transport dies (VM stopped, exec exited) or we
	// get a termination signal; either way tear the child down on the way out.
	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		select {
		case <-sigc:
		case <-session.CloseChan():
		}
		ln.Close()
		session.Close()
		killGroup(child)
		cancel()
	}()

	for {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		go func(c net.Conn) {
			defer c.Close()
			stream, err := session.Open()
			if err != nil {
				return
			}
			splice(c, stream)
		}(conn)
	}
}

func killGroup(cmd *exec.Cmd) {
	if cmd.Process != nil {
		// Negative PID targets the whole process group (Setpgid above).
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}
}

// --- guest side ------------------------------------------------------------

func runServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	target := fs.String("target", "", "guest address to forward each stream to (HOST:PORT)")
	_ = fs.Parse(args)
	if *target == "" {
		log.Fatal("serve: --target HOST:PORT is required")
	}

	session, err := yamux.Server(stdio{in: os.Stdin, out: os.Stdout}, muxConfig())
	if err != nil {
		log.Fatalf("yamux server: %v", err)
	}
	for {
		stream, err := session.Accept()
		if err != nil {
			// EOF: the host closed the exec channel. Nothing left to serve.
			return
		}
		go func(s net.Conn) {
			defer s.Close()
			up, err := net.Dial("tcp", *target)
			if err != nil {
				return
			}
			splice(s, up)
		}(stream)
	}
}
