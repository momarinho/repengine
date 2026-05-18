package fitness

import (
	"regexp"
	"strconv"
	"strings"
)

var numberPattern = regexp.MustCompile(`-?\d+(?:\.\d+)?`)

// FirstNumberString extracts the first numeric token from a free-form string.
// It keeps the raw string contract intact while allowing canonical numeric
// columns to be populated for analytics and constraints.
func FirstNumberString(value string) (float64, bool) {
	match := numberPattern.FindString(strings.TrimSpace(value))
	if match == "" {
		return 0, false
	}

	number, err := strconv.ParseFloat(match, 64)
	if err != nil {
		return 0, false
	}

	return number, true
}

func OptionalFirstNumberString(value string) any {
	number, ok := FirstNumberString(value)
	if !ok {
		return nil
	}
	return number
}
