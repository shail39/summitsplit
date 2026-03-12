package store

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"summitsplit.com/internal/models"
)

func (s *Store) AddExpense(tripID, paidByID, description, category string, amount float64, date time.Time, splits []models.ExpenseSplit) (*models.Expense, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	e := &models.Expense{
		ID:          uuid.NewString(),
		TripID:      tripID,
		PaidByID:    paidByID,
		Description: description,
		Amount:      amount,
		Category:    category,
		Date:        date,
		CreatedAt:   time.Now(),
	}

	_, err = tx.Exec(
		`INSERT INTO expenses (id, trip_id, paid_by_id, description, amount, category, date, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		e.ID, e.TripID, e.PaidByID, e.Description, e.Amount, e.Category, e.Date, e.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert expense: %w", err)
	}

	for _, sp := range splits {
		sp.ExpenseID = e.ID
		_, err = tx.Exec(
			`INSERT INTO expense_splits (expense_id, member_id, amount) VALUES ($1, $2, $3)`,
			sp.ExpenseID, sp.MemberID, sp.Amount,
		)
		if err != nil {
			return nil, fmt.Errorf("insert split: %w", err)
		}
	}

	return e, tx.Commit()
}

func (s *Store) ListExpenses(tripID string) ([]models.Expense, error) {
	rows, err := s.db.Query(
		`SELECT id, trip_id, paid_by_id, description, amount, category, date, created_at FROM expenses WHERE trip_id = $1 ORDER BY date DESC`,
		tripID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var expenses []models.Expense
	for rows.Next() {
		var e models.Expense
		if err := rows.Scan(&e.ID, &e.TripID, &e.PaidByID, &e.Description, &e.Amount, &e.Category, &e.Date, &e.CreatedAt); err != nil {
			return nil, err
		}
		expenses = append(expenses, e)
	}
	return expenses, rows.Err()
}

// Balances computes net balance for each member in a trip, accounting for recorded payments.
func (s *Store) Balances(tripID string) ([]models.Balance, error) {
	members, err := s.ListMembers(tripID)
	if err != nil {
		return nil, err
	}

	paid := make(map[string]float64)
	owed := make(map[string]float64)

	rows, err := s.db.Query(`SELECT paid_by_id, amount FROM expenses WHERE trip_id = $1`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var amount float64
		if err := rows.Scan(&id, &amount); err != nil {
			return nil, err
		}
		paid[id] += amount
	}

	splitRows, err := s.db.Query(
		`SELECT es.member_id, es.amount FROM expense_splits es JOIN expenses e ON e.id = es.expense_id WHERE e.trip_id = $1`,
		tripID,
	)
	if err != nil {
		return nil, err
	}
	defer splitRows.Close()
	for splitRows.Next() {
		var id string
		var amount float64
		if err := splitRows.Scan(&id, &amount); err != nil {
			return nil, err
		}
		owed[id] += amount
	}

	// Apply recorded payments: from pays to → from's net improves, to's net reduces
	payments, err := s.ListPayments(tripID)
	if err != nil {
		return nil, err
	}
	for _, p := range payments {
		paid[p.FromID] += p.Amount
		paid[p.ToID] -= p.Amount
	}

	balances := make([]models.Balance, 0, len(members))
	for _, m := range members {
		balances = append(balances, models.Balance{
			Member:     m,
			TotalPaid:  paid[m.ID],
			TotalOwed:  owed[m.ID],
			NetBalance: paid[m.ID] - owed[m.ID],
		})
	}
	return balances, nil
}

// Settlements computes the minimum set of transfers to settle all debts.
func (s *Store) Settlements(tripID string) ([]models.Settlement, error) {
	balances, err := s.Balances(tripID)
	if err != nil {
		return nil, err
	}

	type entry struct {
		member models.Member
		amount float64
	}

	var creditors, debtors []entry
	for _, b := range balances {
		if b.NetBalance > 0.005 {
			creditors = append(creditors, entry{b.Member, b.NetBalance})
		} else if b.NetBalance < -0.005 {
			debtors = append(debtors, entry{b.Member, -b.NetBalance})
		}
	}

	var settlements []models.Settlement
	i, j := 0, 0
	for i < len(creditors) && j < len(debtors) {
		amount := min(creditors[i].amount, debtors[j].amount)
		settlements = append(settlements, models.Settlement{
			From:   debtors[j].member,
			To:     creditors[i].member,
			Amount: amount,
		})
		creditors[i].amount -= amount
		debtors[j].amount -= amount
		if creditors[i].amount < 0.005 {
			i++
		}
		if debtors[j].amount < 0.005 {
			j++
		}
	}
	return settlements, nil
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
