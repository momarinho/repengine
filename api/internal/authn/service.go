package authn

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
	"golang.org/x/crypto/bcrypt"
)

type RegisterInput struct {
	Email    string
	Password string
}

type RegisterResult struct {
	UserID int
}

type LoginInput struct {
	Email    string
	Password string
}

type LoginResult struct {
	UserID int
	Token  string
}

type Account struct {
	UserID    int       `json:"user_id"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpdateAccountInput struct {
	UserID          int
	Email           string
	CurrentPassword string
	NewPassword     string
}

type UpdateAccountResult struct {
	Account Account `json:"account"`
}

type DeleteAccountInput struct {
	UserID          int
	CurrentPassword string
}

type RequestPasswordResetInput struct {
	Email string
}

type RequestPasswordResetResult struct {
	ResetToken string `json:"reset_token,omitempty"`
}

type ResetPasswordInput struct {
	Token       string
	NewPassword string
}

type Service struct {
	repo authRepo
	now  func() time.Time
}

func NewService(repo authRepo) *Service {
	return &Service{
		repo: repo,
		now: func() time.Time {
			return time.Now().UTC()
		},
	}
}

func (s *Service) Register(ctx context.Context, in RegisterInput) (RegisterResult, error) {
	if err := ValidateRegistrationInput(in.Email, in.Password); err != nil {
		return RegisterResult{}, apperrors.ErrBadRequest(err.Error())
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return RegisterResult{}, apperrors.ErrInternal()
	}

	user, err := s.repo.CreateUser(ctx, NormalizeEmail(in.Email), string(hash))
	if err != nil {
		if IsUniqueViolation(err) {
			return RegisterResult{}, apperrors.ErrBadRequest("email already exists")
		}
		return RegisterResult{}, apperrors.ErrInternal()
	}

	return RegisterResult{UserID: user.ID}, nil
}

func (s *Service) Login(ctx context.Context, in LoginInput) (LoginResult, error) {
	if err := ValidateLoginInput(in.Email, in.Password); err != nil {
		return LoginResult{}, apperrors.ErrBadRequest(err.Error())
	}

	user, err := s.repo.FindUserByEmail(ctx, NormalizeEmail(in.Email))
	if err != nil {
		if IsNotFound(err) {
			return LoginResult{}, apperrors.ErrUnauthorized()
		}
		return LoginResult{}, apperrors.ErrInternal()
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)); err != nil {
		return LoginResult{}, apperrors.ErrUnauthorized()
	}

	token, err := SignToken(user.ID, user.TokenVersion, s.now())
	if err != nil {
		return LoginResult{}, apperrors.ErrInternal()
	}

	return LoginResult{
		UserID: user.ID,
		Token:  token,
	}, nil
}

func (s *Service) Logout(ctx context.Context, userID int) error {
	if userID <= 0 {
		return apperrors.ErrUnauthorized()
	}

	if err := s.repo.IncrementTokenVersion(ctx, userID); err != nil {
		if IsNotFound(err) {
			return apperrors.ErrUnauthorized()
		}
		return apperrors.ErrInternal()
	}

	return nil
}

func (s *Service) AuthenticateToken(ctx context.Context, tokenString string) (*Claims, error) {
	claims, err := ParseToken(tokenString)
	if err != nil {
		return nil, apperrors.ErrUnauthorized()
	}

	tokenVersion, err := s.repo.GetTokenVersionByUserID(ctx, claims.UserID)
	if err != nil {
		if IsNotFound(err) {
			return nil, apperrors.ErrUnauthorized()
		}
		return nil, apperrors.ErrUnauthorized()
	}

	if tokenVersion != claims.TokenVersion {
		return nil, apperrors.ErrUnauthorized()
	}

	return claims, nil
}

func (s *Service) GetAccount(ctx context.Context, userID int) (Account, error) {
	if userID <= 0 {
		return Account{}, apperrors.ErrUnauthorized()
	}

	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil {
		if IsNotFound(err) {
			return Account{}, apperrors.ErrUnauthorized()
		}
		return Account{}, apperrors.ErrInternal()
	}

	return toAccount(user), nil
}

func (s *Service) UpdateAccount(ctx context.Context, in UpdateAccountInput) (UpdateAccountResult, error) {
	if in.UserID <= 0 {
		return UpdateAccountResult{}, apperrors.ErrUnauthorized()
	}
	if strings.TrimSpace(in.CurrentPassword) == "" {
		return UpdateAccountResult{}, apperrors.ErrBadRequest("current_password is required")
	}

	user, err := s.repo.FindUserByID(ctx, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return UpdateAccountResult{}, apperrors.ErrUnauthorized()
		}
		return UpdateAccountResult{}, apperrors.ErrInternal()
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.CurrentPassword)); err != nil {
		return UpdateAccountResult{}, apperrors.ErrBadRequest("current password is incorrect")
	}

	var nextEmail *string
	normalizedEmail := NormalizeEmail(in.Email)
	if normalizedEmail != "" && !strings.EqualFold(normalizedEmail, user.Email) {
		if err := ValidateEmailInput(normalizedEmail); err != nil {
			return UpdateAccountResult{}, apperrors.ErrBadRequest(err.Error())
		}
		nextEmail = &normalizedEmail
	}

	var nextPasswordHash *string
	if strings.TrimSpace(in.NewPassword) != "" {
		if err := ValidatePasswordInput(in.NewPassword); err != nil {
			return UpdateAccountResult{}, apperrors.ErrBadRequest(err.Error())
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(in.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			return UpdateAccountResult{}, apperrors.ErrInternal()
		}
		hashValue := string(hash)
		nextPasswordHash = &hashValue
	}

	if nextEmail == nil && nextPasswordHash == nil {
		return UpdateAccountResult{}, apperrors.ErrBadRequest("no account changes provided")
	}

	updated, err := s.repo.UpdateUserCredentials(ctx, in.UserID, nextEmail, nextPasswordHash)
	if err != nil {
		if IsUniqueViolation(err) {
			return UpdateAccountResult{}, apperrors.ErrBadRequest("email already exists")
		}
		if IsNotFound(err) {
			return UpdateAccountResult{}, apperrors.ErrUnauthorized()
		}
		return UpdateAccountResult{}, apperrors.ErrInternal()
	}

	return UpdateAccountResult{
		Account: toAccount(updated),
	}, nil
}

func (s *Service) DeleteAccount(ctx context.Context, in DeleteAccountInput) error {
	if in.UserID <= 0 {
		return apperrors.ErrUnauthorized()
	}
	if strings.TrimSpace(in.CurrentPassword) == "" {
		return apperrors.ErrBadRequest("current_password is required")
	}

	user, err := s.repo.FindUserByID(ctx, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return apperrors.ErrUnauthorized()
		}
		return apperrors.ErrInternal()
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.CurrentPassword)); err != nil {
		return apperrors.ErrBadRequest("current password is incorrect")
	}

	if err := s.repo.DeleteUser(ctx, in.UserID); err != nil {
		if IsNotFound(err) {
			return apperrors.ErrUnauthorized()
		}
		return apperrors.ErrInternal()
	}

	return nil
}

func (s *Service) RequestPasswordReset(ctx context.Context, in RequestPasswordResetInput) (RequestPasswordResetResult, error) {
	if err := ValidateEmailInput(in.Email); err != nil {
		return RequestPasswordResetResult{}, apperrors.ErrBadRequest(err.Error())
	}

	user, err := s.repo.FindUserByEmail(ctx, NormalizeEmail(in.Email))
	if err != nil {
		if IsNotFound(err) {
			return RequestPasswordResetResult{}, nil
		}
		return RequestPasswordResetResult{}, apperrors.ErrInternal()
	}

	token, tokenHash, err := generateResetToken()
	if err != nil {
		return RequestPasswordResetResult{}, apperrors.ErrInternal()
	}

	if err := s.repo.CreatePasswordResetToken(ctx, user.ID, tokenHash, s.now().Add(time.Hour).Unix()); err != nil {
		return RequestPasswordResetResult{}, apperrors.ErrInternal()
	}

	return RequestPasswordResetResult{
		ResetToken: token,
	}, nil
}

func (s *Service) ResetPassword(ctx context.Context, in ResetPasswordInput) error {
	if strings.TrimSpace(in.Token) == "" {
		return apperrors.ErrBadRequest("token is required")
	}
	if err := ValidatePasswordInput(in.NewPassword); err != nil {
		return apperrors.ErrBadRequest(err.Error())
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return apperrors.ErrInternal()
	}

	if err := s.repo.ConsumePasswordResetToken(ctx, hashResetToken(in.Token), string(hash)); err != nil {
		if IsNotFound(err) {
			return apperrors.ErrBadRequest("password reset token is invalid or expired")
		}
		return apperrors.ErrInternal()
	}

	return nil
}

func toAccount(user User) Account {
	return Account{
		UserID:    user.ID,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
	}
}

func generateResetToken() (string, string, error) {
	var raw [32]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return "", "", fmt.Errorf("generate reset token: %w", err)
	}

	token := base64.RawURLEncoding.EncodeToString(raw[:])
	return token, hashResetToken(token), nil
}

func hashResetToken(token string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(token)))
	return hex.EncodeToString(sum[:])
}
