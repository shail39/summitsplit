package store

import (
	"time"

	"github.com/google/uuid"
	"summitsplit.com/internal/models"
)

func (s *Store) RecordPayment(tripID, fromID, toID string, amount float64, note string) (*models.Payment, error) {
	p := &models.Payment{
		ID:        uuid.NewString(),
		TripID:    tripID,
		FromID:    fromID,
		ToID:      toID,
		Amount:    amount,
		Note:      note,
		CreatedAt: time.Now(),
	}
	_, err := s.db.Exec(
		`INSERT INTO payments (id, trip_id, from_id, to_id, amount, note, created_at) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		p.ID, p.TripID, p.FromID, p.ToID, p.Amount, p.Note, p.CreatedAt,
	)
	return p, err
}

func (s *Store) ListPayments(tripID string) ([]models.Payment, error) {
	rows, err := s.db.Query(
		`SELECT id, trip_id, from_id, to_id, amount, COALESCE(note,''), created_at FROM payments WHERE trip_id = $1 ORDER BY created_at DESC`,
		tripID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Payment
	for rows.Next() {
		var p models.Payment
		if err := rows.Scan(&p.ID, &p.TripID, &p.FromID, &p.ToID, &p.Amount, &p.Note, &p.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
