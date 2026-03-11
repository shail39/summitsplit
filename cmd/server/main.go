package main

import (
	"log"
	"net/http"
	"os"

	"summitsplit.com/internal/api"
	"summitsplit.com/internal/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://summitsplit:summitsplit@localhost:5432/summitsplit?sslmode=disable"
	}

	db, err := store.New(dsn)
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	defer db.Close()

	if err := db.Migrate(); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	router := api.NewRouter(db)

	log.Printf("SummitSplit running on http://localhost:%s", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
