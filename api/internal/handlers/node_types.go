package handlers

import (
	"context"
	"encoding/json"

	"github.com/gofiber/fiber/v2"
	"github.com/momarinho/rep_engine/internal/db"
)

type NodeType struct {
	ID          int            `json:"id"`
	Slug        string         `json:"slug"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Icon        string         `json:"icon"`
	Schema      map[string]any `json:"schema"`
}

var nodeTypesCache map[string]NodeType

func LoadNodeTypesCache(ctx context.Context) error {
	rows, err := db.Pool.Query(ctx, `SELECT id, slug, name, description, icon, schema FROM node_types`)
	if err != nil {
		return err
	}
	defer rows.Close()

	nodeTypesCache = make(map[string]NodeType)
	for rows.Next() {
		var nt NodeType
		var schemaJSON []byte
		if err := rows.Scan(&nt.ID, &nt.Slug, &nt.Name, &nt.Description, &nt.Icon, &schemaJSON); err != nil {
			return err
		}
		if err := json.Unmarshal(schemaJSON, &nt.Schema); err != nil {
			return err
		}
		nodeTypesCache[nt.Slug] = nt
	}
	return nil
}

func GetNodeTypes(c *fiber.Ctx) error {
	types := make([]NodeType, 0, len(nodeTypesCache))
	for _, nt := range nodeTypesCache {
		types = append(types, nt)
	}
	return c.JSON(types)
}

func GetNodeTypeBySlug(c *fiber.Ctx) error {
	slug := c.Params("slug")
	nt, ok := nodeTypesCache[slug]
	if !ok {
		return c.Status(404).JSON(fiber.Map{"error": "node type not found"})
	}
	return c.JSON(nt)
}
