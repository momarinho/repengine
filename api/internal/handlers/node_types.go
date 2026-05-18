package handlers

import (
	"context"
	"encoding/json"
	"sort"

	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type NodeType struct {
	ID          int            `json:"id"`
	Slug        string         `json:"slug"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Icon        string         `json:"icon"`
	Schema      map[string]any `json:"schema"`
}

type nodeTypeQueryer interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}

func LoadNodeTypesCache(ctx context.Context, q nodeTypeQueryer) (map[string]NodeType, error) {
	rows, err := q.Query(ctx, `SELECT id, slug, name, description, icon, schema FROM node_types`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	nodeTypes := make(map[string]NodeType)
	for rows.Next() {
		var nt NodeType
		var schemaJSON []byte
		if err := rows.Scan(&nt.ID, &nt.Slug, &nt.Name, &nt.Description, &nt.Icon, &schemaJSON); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(schemaJSON, &nt.Schema); err != nil {
			return nil, err
		}
		nodeTypes[nt.Slug] = nt
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return nodeTypes, nil
}

func (a *App) GetNodeTypes(c *fiber.Ctx) error {
	types := make([]NodeType, 0, len(a.nodeTypes))
	for _, nt := range a.nodeTypes {
		types = append(types, nt)
	}

	sort.Slice(types, func(i, j int) bool {
		return types[i].ID < types[j].ID
	})

	return c.JSON(types)
}

func (a *App) GetNodeTypeBySlug(c *fiber.Ctx) error {
	slug := c.Params("slug")
	nt, ok := a.nodeTypes[slug]
	if !ok {
		return apperrors.WriteAppError(c, apperrors.New(fiber.StatusNotFound, "NOT_FOUND", "Node type not found"))
	}
	return c.JSON(nt)
}
