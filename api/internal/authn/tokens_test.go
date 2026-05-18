package authn

import (
	"testing"
	"time"
)

func TestSignAndParseToken(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-value")
	t.Setenv("JWT_ISSUER", "repengine-api")
	t.Setenv("JWT_AUDIENCE", "repengine-web")

	now := time.Date(2026, 5, 18, 12, 0, 0, 0, time.UTC)
	token, err := SignToken(42, 3, now)
	if err != nil {
		t.Fatalf("SignToken returned error: %v", err)
	}

	claims, err := ParseToken(token)
	if err != nil {
		t.Fatalf("ParseToken returned error: %v", err)
	}

	if claims.UserID != 42 {
		t.Fatalf("expected user_id 42, got %d", claims.UserID)
	}
	if claims.TokenVersion != 3 {
		t.Fatalf("expected token_version 3, got %d", claims.TokenVersion)
	}
	if claims.Issuer != "repengine-api" {
		t.Fatalf("expected issuer repengine-api, got %q", claims.Issuer)
	}
	if len(claims.Audience) != 1 || claims.Audience[0] != "repengine-web" {
		t.Fatalf("expected audience repengine-web, got %#v", claims.Audience)
	}
}

func TestParseTokenRejectsWrongAudience(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-value")
	t.Setenv("JWT_ISSUER", "repengine-api")
	t.Setenv("JWT_AUDIENCE", "repengine-web")

	token, err := SignToken(7, 0, time.Now().UTC())
	if err != nil {
		t.Fatalf("SignToken returned error: %v", err)
	}

	t.Setenv("JWT_AUDIENCE", "different-audience")

	if _, err := ParseToken(token); err == nil {
		t.Fatal("expected ParseToken to reject token with wrong audience")
	}
}
