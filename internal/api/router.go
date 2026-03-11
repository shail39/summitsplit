package api

import (
	"net/http"

	"summitsplit.com/internal/api/handlers"
	"summitsplit.com/internal/store"
)

func NewRouter(db *store.Store) http.Handler {
	mux := http.NewServeMux()

	h := handlers.New(db)

	// Web UI
	mux.HandleFunc("GET /", h.Home)
	mux.HandleFunc("POST /join", h.JoinTrip)
	mux.HandleFunc("GET /trips/new", h.NewTripForm)
	mux.HandleFunc("POST /trips", h.CreateTrip)
	mux.HandleFunc("GET /trips/{id}", h.TripDetail)
	mux.HandleFunc("POST /trips/{id}/members", h.AddMember)
	mux.HandleFunc("GET /trips/{id}/expenses/new", h.NewExpenseForm)
	mux.HandleFunc("POST /trips/{id}/expenses", h.AddExpense)
	mux.HandleFunc("GET /trips/{id}/settle", h.Settle)

	// JSON API (Flutter-ready)
	mux.HandleFunc("GET /api/trips", h.APIListTrips)
	mux.HandleFunc("POST /api/trips", h.APICreateTrip)
	mux.HandleFunc("GET /api/trips/{id}", h.APIGetTrip)
	mux.HandleFunc("GET /api/trips/{id}/members", h.APIListMembers)
	mux.HandleFunc("POST /api/trips/{id}/members", h.APIAddMember)
	mux.HandleFunc("GET /api/trips/{id}/expenses", h.APIListExpenses)
	mux.HandleFunc("POST /api/trips/{id}/expenses", h.APIAddExpense)
	mux.HandleFunc("GET /api/trips/{id}/balances", h.APIBalances)
	mux.HandleFunc("GET /api/trips/{id}/settlements", h.APISettlements)

	// Static files
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir("web/static"))))

	return mux
}
