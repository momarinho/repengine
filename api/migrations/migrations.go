// Package migrations exposes the embedded SQL migration files so other
// packages (e.g. internal/db) can read them without needing relative ".."
// paths in their own //go:embed directives, which are not supported by Go.
package migrations

import "embed"

// FS contains all *.sql migration files in this directory.
//
//go:embed *.sql
var FS embed.FS
