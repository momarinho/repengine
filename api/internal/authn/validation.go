package authn

import (
	"fmt"
	"net/mail"
	"strings"
)

const (
	minPasswordLength = 8
	maxPasswordLength = 72
)

func ValidateRegistrationInput(email, password string) error {
	normalizedEmail := NormalizeEmail(email)
	if normalizedEmail == "" {
		return fmt.Errorf("email is required")
	}
	if len(normalizedEmail) > 254 {
		return fmt.Errorf("email is too long")
	}

	parsed, err := mail.ParseAddress(normalizedEmail)
	if err != nil || !strings.EqualFold(parsed.Address, normalizedEmail) {
		return fmt.Errorf("email is invalid")
	}

	if strings.TrimSpace(password) == "" {
		return fmt.Errorf("password is required")
	}
	if len(password) < minPasswordLength {
		return fmt.Errorf("password must be at least %d characters", minPasswordLength)
	}
	if len(password) > maxPasswordLength {
		return fmt.Errorf("password must be at most %d characters", maxPasswordLength)
	}

	return nil
}

func ValidateLoginInput(email, password string) error {
	if NormalizeEmail(email) == "" {
		return fmt.Errorf("email is required")
	}
	if password == "" {
		return fmt.Errorf("password is required")
	}
	return nil
}
