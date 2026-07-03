package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	fiberrecover "github.com/gofiber/fiber/v2/middleware/recover"
	authnsvc "github.com/momarinho/rep_engine/internal/authn"
	"github.com/momarinho/rep_engine/internal/config"
	"github.com/momarinho/rep_engine/internal/db"
	"github.com/momarinho/rep_engine/internal/handlers"
	"github.com/momarinho/rep_engine/internal/logger"
	"github.com/momarinho/rep_engine/internal/middleware"
	progressionstatesvc "github.com/momarinho/rep_engine/internal/progression_states"
	templatesvc "github.com/momarinho/rep_engine/internal/templates"
	trainingmaxessvc "github.com/momarinho/rep_engine/internal/training_maxes"
	workflowsvc "github.com/momarinho/rep_engine/internal/workflows"
	workoutsessionsvc "github.com/momarinho/rep_engine/internal/workout_sessions"
)

// version and buildTime are overridden at build time via -ldflags:
//
//	-ldflags "-X main.version=$(git describe --tags) -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
var (
	version         = "dev"
	buildTime       = "unknown"
	serverStartTime = time.Now()
)

func main() {
	cfg, err := config.Load(version, buildTime)
	if err != nil {
		slog.Error("failed to load config", "err", err)
		os.Exit(1)
	}

	log := logger.New(cfg.LogLevel)
	slog.SetDefault(log)

	if err := db.Connect(); err != nil {
		slog.Error("failed to connect database", "err", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.RunMigrations(context.Background()); err != nil {
		slog.Error("failed to run migrations", "err", err)
		os.Exit(1)
	}

	if err := db.SeedNodeTypes(context.Background()); err != nil {
		slog.Error("failed to seed node types", "err", err)
		os.Exit(1)
	}

	if err := db.SeedTemplates(context.Background()); err != nil {
		slog.Error("failed to seed templates", "err", err)
		os.Exit(1)
	}

	nodeTypesCache, err := handlers.LoadNodeTypesCache(context.Background(), db.Pool)
	if err != nil {
		slog.Error("failed to load node types cache", "err", err)
		os.Exit(1)
	}

	authRepo := authnsvc.NewRepository(db.Pool)
	authService := authnsvc.NewService(authRepo)

	workflowRepo := workflowsvc.NewRepository(db.Pool)
	workflowService := workflowsvc.NewService(workflowRepo)

	templateRepo := templatesvc.NewRepository(db.Pool)
	templateWorker := templatesvc.NewCloneWorker(templateRepo)
	templateService := templatesvc.NewService(templateRepo, templateWorker)

	progressionStateRepo := progressionstatesvc.NewRepository(db.Pool)
	progressionStateService := progressionstatesvc.NewService(progressionStateRepo)

	trainingMaxesRepo := trainingmaxessvc.NewRepository(db.Pool)
	trainingMaxesService := trainingmaxessvc.NewService(trainingMaxesRepo)

	workoutSessionRepo := workoutsessionsvc.NewRepository(db.Pool)
	workoutSessionService := workoutsessionsvc.NewService(workoutSessionRepo, progressionStateService)

	h := handlers.NewApp(handlers.Dependencies{
		Auth:            authService,
		Workflows:       workflowService,
		Templates:       templateService,
		Progression:     progressionStateService,
		TrainingMaxes:   trainingMaxesService,
		WorkoutSessions: workoutSessionService,
		NodeTypes:       nodeTypesCache,
	})
	requireAuth := middleware.RequireAuth(authService)

	app := fiber.New()

	app.Use(fiberrecover.New(fiberrecover.Config{
		EnableStackTrace: true,
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins:     cfg.CORSOrigins,
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization",
		AllowCredentials: true,
	}))
	app.Use(middleware.RequestID())
	app.Use(middleware.TimeoutMiddleware(10 * time.Second))
	app.Use(limiter.New(limiter.Config{
		Max:        100,
		Expiration: 1 * time.Minute,
		KeyGenerator: func(c *fiber.Ctx) string {
			return c.IP()
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(429).JSON(fiber.Map{
				"error": "rate limit exceeded",
			})
		},
	}))
	app.Use(middleware.Logging(slog.Default()))
	app.Use(middleware.Metrics())

	app.Get("/metrics", middleware.MetricsHandler())

	app.Get("/health", func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.Context(), 2*time.Second)
		defer cancel()

		dbHealth := "ok"
		if err := db.Pool.Ping(ctx); err != nil {
			dbHealth = "unhealthy"
		}

		uptime := time.Since(serverStartTime).Truncate(time.Second).String()

		return c.JSON(fiber.Map{
			"status":  "ok",
			"db":      dbHealth,
			"uptime":  uptime,
			"version": version,
			"env":     cfg.AppEnv,
		})
	})

	auth := app.Group("/auth")
	auth.Post("/register", middleware.AuthRateLimit(5, time.Minute), h.Register)
	auth.Post("/login", middleware.AuthRateLimit(10, time.Minute), h.Login)
	auth.Post("/logout", requireAuth, h.Logout)
	auth.Get("/me", requireAuth, h.GetAccount)
	auth.Put("/me", requireAuth, h.UpdateAccount)
	auth.Delete("/me", requireAuth, h.DeleteAccount)
	auth.Post("/password-reset/request", middleware.AuthRateLimit(5, time.Minute), h.RequestPasswordReset)
	auth.Post("/password-reset/confirm", middleware.AuthRateLimit(5, time.Minute), h.ResetPassword)
	app.Get("/node-types", h.GetNodeTypes)
	app.Get("/node-types/:slug", h.GetNodeTypeBySlug)

	workflows := app.Group("/workflows", requireAuth)
	workflows.Get("/", h.ListWorkflows)
	workflows.Post("/", h.CreateWorkflow)
	workflows.Get("/:id", h.GetWorkflow)
	workflows.Put("/:id", h.UpdateWorkflow)
	workflows.Delete("/:id", h.DeleteWorkflow)
	workflows.Post("/:id/versions", h.CreateVersion)
	workflows.Get("/:id/versions", h.ListVersions)
	workflows.Post("/:id/versions/:versionId/restore", h.RestoreVersion)
	workflows.Get("/:id/sessions", h.ListWorkoutSessions)
	workflows.Post("/:id/sessions", h.StartWorkoutSession)
	workflows.Get("/:id/progression-states", h.ListProgressionStates)
	workflows.Get("/:id/analytics", h.GetWorkoutAnalytics)

	templates := app.Group("/templates", requireAuth)
	templates.Get("/", h.ListTemplates)
	templates.Get("/:id", h.GetTemplate)
	templates.Post("/:id/clone", h.CloneTemplate)

	cloneJobs := app.Group("/clone-jobs", requireAuth)
	cloneJobs.Get("/:id", h.GetCloneJob)

	workoutSessions := app.Group("/workout-sessions", requireAuth)
	workoutSessions.Get("/:id", h.GetWorkoutSession)
	workoutSessions.Post("/:id/logs", h.CreateWorkoutSetLog)
	workoutSessions.Put("/:id/logs/:logId", h.UpdateWorkoutSetLog)
	workoutSessions.Post("/:id/complete", h.CompleteWorkoutSession)
	workoutSessions.Post("/:id/abandon", h.AbandonWorkoutSession)

	trainingMaxes := app.Group("/training-maxes", requireAuth)
	trainingMaxes.Get("/", h.ListTrainingMaxes)
	trainingMaxes.Post("/", h.UpsertTrainingMax)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	go func() {
		if err := app.Listen(":" + cfg.Port); err != nil {
			slog.Error("server error", "err", err)
		}
	}()

	slog.Info("server started", "addr", ":"+cfg.Port, "version", version, "env", cfg.AppEnv)

	<-quit
	slog.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := app.ShutdownWithContext(ctx); err != nil {
		slog.Error("graceful shutdown failed", "err", err)
	} else {
		slog.Info("server stopped gracefully")
	}
}
