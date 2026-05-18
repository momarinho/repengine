package authn

import "testing"

func TestValidateRegistrationInput(t *testing.T) {
	tests := []struct {
		name     string
		email    string
		password string
		wantErr  bool
	}{
		{name: "valid", email: " User@Example.com ", password: "strongpass1", wantErr: false},
		{name: "missing email", email: "   ", password: "strongpass1", wantErr: true},
		{name: "invalid email", email: "not-an-email", password: "strongpass1", wantErr: true},
		{name: "short password", email: "user@example.com", password: "short", wantErr: true},
		{name: "long password", email: "user@example.com", password: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateRegistrationInput(tt.email, tt.password)
			if tt.wantErr && err == nil {
				t.Fatal("expected error, got nil")
			}
			if !tt.wantErr && err != nil {
				t.Fatalf("expected nil error, got %v", err)
			}
		})
	}
}
