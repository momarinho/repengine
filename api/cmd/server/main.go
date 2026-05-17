package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/momarinho/rep_engine/internal/db"
	"github.com/momarinho/rep_engine/internal/handlers"
	"github.com/momarinho/rep_engine/internal/logger"
	"github.com/momarinho/rep_engine/internal/middleware"
	templatesvc "github.com/momarinho/rep_engine/internal/templates"
	workflowsvc "github.com/momarinho/rep_engine/internal/workflows"
	workoutsessionsvc "github.com/momarinho/rep_engine/internal/workout_sessions"
)

var serverStartTime = time.Now()

func main() {
	log := logger.Init()
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

	if err := handlers.LoadNodeTypesCache(context.Background()); err != nil {
		slog.Error("failed to load node types cache", "err", err)
		os.Exit(1)
	}

	workflowRepo := workflowsvc.NewRepository(db.Pool)
	workflowService := workflowsvc.NewService(workflowRepo)
	handlers.SetWorkflowService(workflowService)

	templateRepo := templatesvc.NewRepository(db.Pool)
	templateWorker := templatesvc.NewCloneWorker(templateRepo)
	templateService := templatesvc.NewService(templateRepo, templateWorker)
	handlers.SetTemplateService(templateService)

	workoutSessionRepo := workoutsessionsvc.NewRepository(db.Pool)
	workoutSessionService := workoutsessionsvc.NewService(workoutSessionRepo)
	handlers.SetWorkoutSessionService(workoutSessionService)

	app := fiber.New()

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
			"version": "1.0.0",
		})
	})

	auth := app.Group("/auth")
	auth.Post("/register", handlers.Register)
	auth.Post("/login", handlers.Login)
	auth.Post("/logout", handlers.Logout)
	app.Get("/node-types", handlers.GetNodeTypes)
	app.Get("/node-types/:slug", handlers.GetNodeTypeBySlug)

	workflows := app.Group("/workflows", middleware.RequireAuth)
	workflows.Get("/", handlers.ListWorkflows)
	workflows.Post("/", handlers.CreateWorkflow)
	workflows.Get("/:id", handlers.GetWorkflow)
	workflows.Put("/:id", handlers.UpdateWorkflow)
	workflows.Delete("/:id", handlers.DeleteWorkflow)
	workflows.Post("/:id/versions", handlers.CreateVersion)
	workflows.Get("/:id/versions", handlers.ListVersions)
	workflows.Get("/:id/sessions", handlers.ListWorkoutSessions)
	workflows.Post("/:id/sessions", handlers.StartWorkoutSession)

	templates := app.Group("/templates", middleware.RequireAuth)
	templates.Get("/", handlers.ListTemplates)
	templates.Get("/:id", handlers.GetTemplate)
	templates.Post("/:id/clone", handlers.CloneTemplate)

	cloneJobs := app.Group("/clone-jobs", middleware.RequireAuth)
	cloneJobs.Get("/:id", handlers.GetCloneJob)

	workoutSessions := app.Group("/workout-sessions", middleware.RequireAuth)
	workoutSessions.Get("/:id", handlers.GetWorkoutSession)
	workoutSessions.Post("/:id/logs", handlers.CreateWorkoutSetLog)
	workoutSessions.Post("/:id/complete", handlers.CompleteWorkoutSession)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	go func() {
		if err := app.Listen(":8080"); err != nil {
			slog.Error("server error", "err", err)
		}
	}()

	slog.Info("server started", "addr", ":8080")

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
