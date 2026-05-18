package authn

import (
	"context"
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
