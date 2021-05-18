package main

import (
	"crypto/tls"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	"golang.org/x/net/http2"
)

var (
	upstream    string
	httpsSocket string
	httpsCert   string
	httpsKey    string
)

func init() {
	flag.StringVar(&upstream, "upstream", "https://localhost:9100", "upstream (http://<ip>:<port>)")
	flag.StringVar(&httpsSocket, "socket", ":8585", "local socket")
	flag.StringVar(&httpsCert, "cert", "./certs/service-cert.pem", "ssl cert")
	flag.StringVar(&httpsKey, "key", "./certs/service-key.pem", "key")
	flag.Parse()
}

func main() {
	log.SetPrefix("[proxy] ")
	log.SetOutput(os.Stdout)
	if upstream == "" {
		log.Fatal("ERROR: missing argument upstream ")
	}
	url, _ := url.Parse(upstream)
	proxy := &Upstream{target: url, proxy: httputil.NewSingleHostReverseProxy(url)}

	mux := http.NewServeMux()
	mux.HandleFunc("/", proxy.handle)
	log.Fatal(http.ListenAndServeTLS(httpsSocket, httpsCert, httpsKey, mux))

}

// Upstream ...
type Upstream struct {
	target *url.URL
	proxy  *httputil.ReverseProxy
}

func (p *Upstream) handle(w http.ResponseWriter, r *http.Request) {
	log.Println("here")
	w.Header().Set("X-Forwarded-For", r.Host)
	p.proxy.Transport =
		&http2.Transport{
			// AllowHTTP: true,
			// DialTLS: func(network, addr string, cfg *tls.Config) (net.Conn, error) {
			// 	ta, err := net.ResolveTCPAddr(network, addr)
			// 	if err != nil {
			// 		return nil, err
			// 	}
			// 	return net.DialTCP(network, nil, ta)
			// },
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		}
	p.proxy.ServeHTTP(w, r)
}
