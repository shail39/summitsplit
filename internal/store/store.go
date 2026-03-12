package store

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

type Store struct {
	db *sql.DB
}

func New(dsn string) (*Store, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

func (s *Store) Migrate() error {
	_, err := s.db.Exec(schema)
	return err
}

const schema = `
CREATE TABLE IF NOT EXISTS trips (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    currency    TEXT NOT NULL DEFAULT 'USD',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS members (
    id      TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    name    TEXT NOT NULL,
    email   TEXT
);

CREATE TABLE IF NOT EXISTS expenses (
    id          TEXT PRIMARY KEY,
    trip_id     TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    paid_by_id  TEXT NOT NULL REFERENCES members(id),
    description TEXT NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    category    TEXT NOT NULL DEFAULT 'other',
    date        TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expense_splits (
    expense_id  TEXT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id   TEXT NOT NULL REFERENCES members(id),
    amount      NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (expense_id, member_id)
);

CREATE TABLE IF NOT EXISTS payments (
    id         TEXT PRIMARY KEY,
    trip_id    TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    from_id    TEXT NOT NULL REFERENCES members(id),
    to_id      TEXT NOT NULL REFERENCES members(id),
    amount     NUMERIC(12,2) NOT NULL,
    note       TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
`
