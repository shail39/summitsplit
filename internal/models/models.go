package models

import "time"

type Trip struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Currency    string    `json:"currency"`
	Emoji       string    `json:"emoji"`
	CreatedAt   time.Time `json:"created_at"`
}

type Member struct {
	ID     string `json:"id"`
	TripID string `json:"trip_id"`
	Name   string `json:"name"`
	Email  string `json:"email,omitempty"`
}

type Expense struct {
	ID          string    `json:"id"`
	TripID      string    `json:"trip_id"`
	PaidByID    string    `json:"paid_by_id"`
	Description string    `json:"description"`
	Amount      float64   `json:"amount"`
	Category    string    `json:"category"`
	Notes       string    `json:"notes,omitempty"`
	Date        time.Time `json:"date"`
	CreatedAt   time.Time `json:"created_at"`
}

type ExpenseSplit struct {
	ExpenseID string  `json:"expense_id"`
	MemberID  string  `json:"member_id"`
	Amount    float64 `json:"amount"`
}

// Balance represents what a member owes or is owed in a trip
type Balance struct {
	Member     Member  `json:"member"`
	TotalPaid  float64 `json:"total_paid"`
	TotalOwed  float64 `json:"total_owed"`
	NetBalance float64 `json:"net_balance"` // positive = owed money, negative = owes money
}

// Settlement represents a suggested payment to settle debts
type Settlement struct {
	From   Member  `json:"from"`
	To     Member  `json:"to"`
	Amount float64 `json:"amount"`
}

// Payment records that someone has paid their debt
type Payment struct {
	ID        string    `json:"id"`
	TripID    string    `json:"trip_id"`
	FromID    string    `json:"from_id"`
	ToID      string    `json:"to_id"`
	Amount    float64   `json:"amount"`
	Note      string    `json:"note,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}
