package test

import (
	dbx "github.com/go-ozzo/ozzo-dbx"
	"github.com/ico12319/devops-project/internal/config"
	"github.com/ico12319/devops-project/pkg/dbcontext"
	"github.com/ico12319/devops-project/pkg/log"
	_ "github.com/lib/pq" // initialize posgresql for test
	"testing"
)

var db *dbcontext.DB

func DB(t *testing.T) *dbcontext.DB {
	t.Helper()

	if db != nil {
		return db
	}

	logger, _ := log.NewForTest()

	// Load config from env only (file optional / empty)
	cfg, err := config.Load("", logger)
	if err != nil {
		t.Fatal(err)
	}

	dbc, err := dbx.MustOpen("postgres", cfg.DSN)
	if err != nil {
		t.Fatal(err)
	}

	dbc.LogFunc = logger.Infof
	db = dbcontext.New(dbc)
	return db
}

// ResetTables truncates all data in the specified tables.
func ResetTables(t *testing.T, db *dbcontext.DB, tables ...string) {
	for _, table := range tables {
		_, err := db.DB().TruncateTable(table).Execute()
		if err != nil {
			t.Error(err)
			t.FailNow()
		}
	}
}
