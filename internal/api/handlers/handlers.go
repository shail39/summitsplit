package handlers

import (
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"summitsplit.com/internal/models"
	"summitsplit.com/internal/store"
)

type Handler struct {
	store *store.Store
	tmpls map[string]*template.Template
}

func New(s *store.Store) *Handler {
	base := filepath.Join("web", "templates", "base.html")
	pages := []string{"home.html", "trip_new.html", "trip_detail.html", "expense_new.html", "settle.html"}
	tmpls := make(map[string]*template.Template, len(pages))
	for _, p := range pages {
		tmpls[p] = template.Must(template.ParseFiles(base, filepath.Join("web", "templates", p)))
	}
	return &Handler{store: s, tmpls: tmpls}
}

// --- Web UI handlers ---

func (h *Handler) Home(w http.ResponseWriter, r *http.Request) {
	h.render(w, "home.html", nil)
}

func (h *Handler) NewTripForm(w http.ResponseWriter, r *http.Request) {
	h.render(w, "trip_new.html", nil)
}

func (h *Handler) CreateTrip(w http.ResponseWriter, r *http.Request) {
	name := r.FormValue("name")
	desc := r.FormValue("description")
	currency := r.FormValue("currency")
	if currency == "" {
		currency = "USD"
	}
	trip, err := h.store.CreateTrip(name, desc, currency)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/trips/"+trip.ID, http.StatusSeeOther)
}

func (h *Handler) TripDetail(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	trip, err := h.store.GetTrip(id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	members, _ := h.store.ListMembers(id)
	expenses, _ := h.store.ListExpenses(id)
	balances, _ := h.store.Balances(id)

	memberMap := make(map[string]string, len(members))
	for _, m := range members {
		memberMap[m.ID] = m.Name
	}

	scheme := "https"
	if r.TLS == nil && r.Header.Get("X-Forwarded-Proto") != "https" {
		scheme = "http"
	}
	inviteURL := fmt.Sprintf("%s://%s/trips/%s", scheme, r.Host, trip.ID)

	h.render(w, "trip_detail.html", map[string]any{
		"Trip":      trip,
		"Members":   members,
		"MemberMap": memberMap,
		"Expenses":  expenses,
		"Balances":  balances,
		"InviteURL": inviteURL,
	})
}

// JoinTrip accepts a pasted invite URL or bare trip ID and redirects to the trip.
func (h *Handler) JoinTrip(w http.ResponseWriter, r *http.Request) {
	code := strings.TrimSpace(r.FormValue("code"))

	// If they pasted a full URL, extract the trip ID from it.
	// Handles: https://host/trips/{id}  or  /trips/{id}  or  just {id}
	if idx := strings.LastIndex(code, "/trips/"); idx != -1 {
		code = strings.TrimSpace(code[idx+len("/trips/"):])
	}
	// Strip any query string or trailing path
	if idx := strings.IndexAny(code, "/?#"); idx != -1 {
		code = code[:idx]
	}

	if code == "" {
		h.render(w, "home.html", map[string]any{"Error": "Please enter a valid trip link or code."})
		return
	}

	if _, err := h.store.GetTrip(code); err != nil {
		h.render(w, "home.html", map[string]any{"Error": "Trip not found. Check the link and try again."})
		return
	}

	http.Redirect(w, r, "/trips/"+code, http.StatusSeeOther)
}

func (h *Handler) AddMember(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	name := r.FormValue("name")
	email := r.FormValue("email")
	if _, err := h.store.AddMember(id, name, email); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/trips/"+id, http.StatusSeeOther)
}

func (h *Handler) NewExpenseForm(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	trip, _ := h.store.GetTrip(id)
	members, _ := h.store.ListMembers(id)
	h.render(w, "expense_new.html", map[string]any{
		"Trip":       trip,
		"Members":    members,
		"Today":      time.Now().Format("2006-01-02"),
		"Categories": []string{"gear", "food", "transport", "accommodation", "other"},
	})
}

func (h *Handler) AddExpense(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	r.ParseForm()

	paidBy := r.FormValue("paid_by")
	desc := r.FormValue("description")
	category := r.FormValue("category")
	var amount float64
	if _, err := parseFloat(r.FormValue("amount"), &amount); err != nil {
		http.Error(w, "invalid amount", http.StatusBadRequest)
		return
	}
	date, _ := time.Parse("2006-01-02", r.FormValue("date"))

	members, _ := h.store.ListMembers(id)
	splitAmnt := amount / float64(len(members))
	var splits []models.ExpenseSplit
	for _, m := range members {
		splits = append(splits, models.ExpenseSplit{MemberID: m.ID, Amount: splitAmnt})
	}

	if _, err := h.store.AddExpense(id, paidBy, desc, category, amount, date, splits); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/trips/"+id, http.StatusSeeOther)
}

func (h *Handler) Settle(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	trip, _ := h.store.GetTrip(id)
	settlements, _ := h.store.Settlements(id)
	h.render(w, "settle.html", map[string]any{
		"Trip":        trip,
		"Settlements": settlements,
	})
}

// --- JSON API handlers ---

func (h *Handler) APIListTrips(w http.ResponseWriter, r *http.Request) {
	trips, err := h.store.ListTrips()
	writeJSON(w, trips, err)
}

func (h *Handler) APICreateTrip(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Currency    string `json:"currency"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if body.Currency == "" {
		body.Currency = "USD"
	}
	trip, err := h.store.CreateTrip(body.Name, body.Description, body.Currency)
	writeJSON(w, trip, err)
}

func (h *Handler) APIGetTrip(w http.ResponseWriter, r *http.Request) {
	trip, err := h.store.GetTrip(r.PathValue("id"))
	writeJSON(w, trip, err)
}

func (h *Handler) APIListMembers(w http.ResponseWriter, r *http.Request) {
	members, err := h.store.ListMembers(r.PathValue("id"))
	writeJSON(w, members, err)
}

func (h *Handler) APIAddMember(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	m, err := h.store.AddMember(r.PathValue("id"), body.Name, body.Email)
	writeJSON(w, m, err)
}

func (h *Handler) APIListExpenses(w http.ResponseWriter, r *http.Request) {
	expenses, err := h.store.ListExpenses(r.PathValue("id"))
	writeJSON(w, expenses, err)
}

func (h *Handler) APIAddExpense(w http.ResponseWriter, r *http.Request) {
	var body struct {
		PaidByID    string                `json:"paid_by_id"`
		Description string                `json:"description"`
		Category    string                `json:"category"`
		Amount      float64               `json:"amount"`
		Date        string                `json:"date"`
		Splits      []models.ExpenseSplit `json:"splits"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	date, _ := time.Parse("2006-01-02", body.Date)
	e, err := h.store.AddExpense(r.PathValue("id"), body.PaidByID, body.Description, body.Category, body.Amount, date, body.Splits)
	writeJSON(w, e, err)
}

func (h *Handler) APIBalances(w http.ResponseWriter, r *http.Request) {
	balances, err := h.store.Balances(r.PathValue("id"))
	writeJSON(w, balances, err)
}

func (h *Handler) APISettlements(w http.ResponseWriter, r *http.Request) {
	settlements, err := h.store.Settlements(r.PathValue("id"))
	writeJSON(w, settlements, err)
}

func (h *Handler) APIListPayments(w http.ResponseWriter, r *http.Request) {
	payments, err := h.store.ListPayments(r.PathValue("id"))
	writeJSON(w, payments, err)
}

func (h *Handler) APIRecordPayment(w http.ResponseWriter, r *http.Request) {
	var body struct {
		FromID string  `json:"from_id"`
		ToID   string  `json:"to_id"`
		Amount float64 `json:"amount"`
		Note   string  `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	p, err := h.store.RecordPayment(r.PathValue("id"), body.FromID, body.ToID, body.Amount, body.Note)
	writeJSON(w, p, err)
}

// --- helpers ---

func (h *Handler) render(w http.ResponseWriter, name string, data any) {
	tmpl, ok := h.tmpls[name]
	if !ok {
		http.Error(w, "template not found: "+name, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	if err := tmpl.ExecuteTemplate(w, name, data); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func writeJSON(w http.ResponseWriter, data any, err error) {
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func parseFloat(s string, out *float64) (float64, error) {
	var v float64
	_, err := fmt.Sscanf(s, "%f", &v)
	*out = v
	return v, err
}
