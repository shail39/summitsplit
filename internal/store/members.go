package store

import (
	"fmt"

	"github.com/google/uuid"
	"summitsplit.com/internal/models"
)

func (s *Store) AddMember(tripID, name, email string) (*models.Member, error) {
	m := &models.Member{
		ID:     uuid.NewString(),
		TripID: tripID,
		Name:   name,
		Email:  email,
	}
	_, err := s.db.Exec(
		`INSERT INTO members (id, trip_id, name, email) VALUES ($1, $2, $3, $4)`,
		m.ID, m.TripID, m.Name, m.Email,
	)
	if err != nil {
		return nil, fmt.Errorf("add member: %w", err)
	}
	return m, nil
}

func (s *Store) DeleteMember(memberID string) error {
	// Check if member has expenses or splits
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM expenses WHERE paid_by_id=$1`, memberID).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("cannot delete member: they have %d expenses", count)
	}

	err = s.db.QueryRow(`SELECT COUNT(*) FROM expense_splits WHERE member_id=$1`, memberID).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("cannot delete member: they are part of %d expense splits", count)
	}

	// Check payments
	err = s.db.QueryRow(`SELECT COUNT(*) FROM payments WHERE from_id=$1 OR to_id=$1`, memberID).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("cannot delete member: they have %d payments", count)
	}

	_, err = s.db.Exec(`DELETE FROM members WHERE id=$1`, memberID)
	return err
}

func (s *Store) ListMembers(tripID string) ([]models.Member, error) {
	rows, err := s.db.Query(`SELECT id, trip_id, name, COALESCE(email,'') FROM members WHERE trip_id = $1`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []models.Member
	for rows.Next() {
		var m models.Member
		if err := rows.Scan(&m.ID, &m.TripID, &m.Name, &m.Email); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}
