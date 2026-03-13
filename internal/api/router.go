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

	// JSON API
	mux.HandleFunc("GET /api/trips", h.APIListTrips)
	mux.HandleFunc("POST /api/trips", h.APICreateTrip)
	mux.HandleFunc("GET /api/trips/{id}", h.APIGetTrip)
	mux.HandleFunc("GET /api/trips/{id}/members", h.APIListMembers)
	mux.HandleFunc("POST /api/trips/{id}/members", h.APIAddMember)
	mux.HandleFunc("GET /api/trips/{id}/expenses", h.APIListExpenses)
	mux.HandleFunc("POST /api/trips/{id}/expenses", h.APIAddExpense)
	mux.HandleFunc("PUT /api/trips/{id}/expenses/{eid}", h.APIUpdateExpense)
	mux.HandleFunc("DELETE /api/trips/{id}/expenses/{eid}", h.APIDeleteExpense)
	mux.HandleFunc("DELETE /api/trips/{id}/members/{mid}", h.APIDeleteMember)
	mux.HandleFunc("GET /api/trips/{id}/balances", h.APIBalances)
	mux.HandleFunc("GET /api/trips/{id}/settlements", h.APISettlements)
	mux.HandleFunc("GET /api/trips/{id}/payments", h.APIListPayments)
	mux.HandleFunc("POST /api/trips/{id}/payments", h.APIRecordPayment)

	// Static files
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir("web/static"))))

	return withCORS(mux)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
