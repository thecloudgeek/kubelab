package probes

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
)

// Liveness probe
func Liveness(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Liveness probe hit")
}

// Readiness probe
func Readiness(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Readiness probe hit")
}

// Health probe
func Health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "ok")
}

// Ping backend
func Ping(w http.ResponseWriter, r *http.Request, beURL *string) {
	if *beURL == "" {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "Backend not specified")
		return
	}

	url := "http://" + *beURL
	fmt.Fprintf(w, "Reaching backend: %s\n\n", url)

	c := &http.Client{}
	req, err := http.NewRequest("GET", url, nil)
	// fetch header foo from the frontend request
	foo := r.Header.Get("foo")
	if foo != "" {
		// pass on the header to the backend
		req.Header.Add("foo", foo)
	}

	resp, err := c.Do(req)
	if err != nil {
		log.Printf("The HTTP request failed with error %s\n", err)
		fmt.Fprintf(w, "== Error ==\n%s\n", err.Error())
		return
	}
	// this call will panic if the previous error handing block did not return
	defer resp.Body.Close()

	data, _ := ioutil.ReadAll(resp.Body)
	fmt.Fprintf(w, "== Result ==\n")
	fmt.Fprintf(w, "%s\n", string(data))
}
