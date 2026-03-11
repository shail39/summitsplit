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

func (s *Store) ListMembers(tripID string) ([]models.Member, error) {
	rows, err := s.db.Query(`SELECT id, trip_id, name, email FROM members WHERE trip_id = $1`, tripID)
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
