// webdavd — a tiny, single-binary WebDAV server with HTTP Basic Auth.
//
// It serves one directory over WebDAV so you can read/write files from any
// WebDAV client (Finder, Cyberduck, Transmit, rclone, Windows "Map network
// drive", mobile apps, ...). It is intentionally minimal: one file, no config,
// everything via flags, and it cross-compiles to almost anything (Pi, NAS,
// MIPS/ARM routers, x86 VPS).
//
// Example:
//
//	webdavd -addr 0.0.0.0:8080 -root /srv/storage -user alice -pass 's3cret'
package main

import (
	"crypto/subtle"
	"flag"
	"log"
	"net/http"

	"golang.org/x/net/webdav"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:8080", "listen address (use 0.0.0.0:8080 to accept LAN connections)")
	root := flag.String("root", ".", "directory to serve")
	user := flag.String("user", "", "basic auth username (empty = no auth; not recommended)")
	pass := flag.String("pass", "", "basic auth password")
	flag.Parse()

	dav := &webdav.Handler{
		FileSystem: webdav.Dir(*root),
		LockSystem: webdav.NewMemLS(),
		Logger: func(r *http.Request, err error) {
			if err != nil {
				log.Printf("%s %s: %v", r.Method, r.URL.Path, err)
			}
		},
	}

	mux := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if *user != "" {
			u, p, ok := r.BasicAuth()
			// constant-time compare avoids leaking credential length/content via timing
			if !ok ||
				subtle.ConstantTimeCompare([]byte(u), []byte(*user)) != 1 ||
				subtle.ConstantTimeCompare([]byte(p), []byte(*pass)) != 1 {
				w.Header().Set("WWW-Authenticate", `Basic realm="webdav"`)
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
		}
		dav.ServeHTTP(w, r)
	})

	log.Printf("webdav serving %s on %s", *root, *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}
