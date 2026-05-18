package authn

import (
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const TokenTTL = 24 * time.Hour

type Claims struct {
	UserID       int `json:"user_id"`
	TokenVersion int `json:"token_version"`
	jwt.RegisteredClaims
}

func SignToken(userID, tokenVersion int, now time.Time) (string, error) {
	claims := Claims{
		UserID:       userID,
		TokenVersion: tokenVersion,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   strconv.Itoa(userID),
			Audience:  jwt.ClaimStrings{JWTAudience()},
			Issuer:    JWTIssuer(),
			ExpiresAt: jwt.NewNumericDate(now.UTC().Add(TokenTTL)),
			IssuedAt:  jwt.NewNumericDate(now.UTC()),
			NotBefore: jwt.NewNumericDate(now.UTC()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(JWTSecret()))
}

func ParseToken(tokenString string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(
		tokenString,
		claims,
		func(token *jwt.Token) (any, error) {
			return []byte(JWTSecret()), nil
		},
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer(JWTIssuer()),
		jwt.WithAudience(JWTAudience()),
	)
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, errors.New("invalid token")
	}
	if claims.UserID <= 0 {
		return nil, fmt.Errorf("invalid user_id claim")
	}
	if claims.TokenVersion < 0 {
		return nil, fmt.Errorf("invalid token_version claim")
	}

	return claims, nil
}
