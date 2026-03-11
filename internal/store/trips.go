package store

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"summitsplit.com/internal/models"
)

func (s *Store) CreateTrip(name, description, currency string) (*models.Trip, error) {
	trip := &models.Trip{
		ID:          uuid.NewString(),
		Name:        name,
		Description: description,
		Currency:    currency,
		CreatedAt:   time.Now(),
	}
	_, err := s.db.Exec(
		`INSERT INTO trips (id, name, description, currency, created_at) VALUES ($1, $2, $3, $4, $5)`,
		trip.ID, trip.Name, trip.Description, trip.Currency, trip.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create trip: %w", err)
	}
	return trip, nil
}

func (s *Store) GetTrip(id string) (*models.Trip, error) {
	row := s.db.QueryRow(`SELECT id, name, COALESCE(description,''), currency, created_at FROM trips WHERE id = $1`, id)
	t := &models.Trip{}
	if err := row.Scan(&t.ID, &t.Name, &t.Description, &t.Currency, &t.CreatedAt); err != nil {
		return nil, fmt.Errorf("get trip: %w", err)
	}
	return t, nil
}

func (s *Store) ListTrips() ([]models.Trip, error) {
	rows, err := s.db.Query(`SELECT id, name, COALESCE(description,''), currency, created_at FROM trips ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trips []models.Trip
	for rows.Next() {
		var t models.Trip
		if err := rows.Scan(&t.ID, &t.Name, &t.Description, &t.Currency, &t.CreatedAt); err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}
	return trips, rows.Err()
}
