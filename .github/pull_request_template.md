## Summary

- 

## Validation

- [ ] `cd api && CGO_ENABLED=0 go test ./...`
- [ ] `cd api && CGO_ENABLED=0 go build ./cmd/server`
- [ ] `cd web && npm run check`
- [ ] `cd web && npm run build`

## Checklist

- [ ] README updated when product surface changed
- [ ] OpenAPI updated when API contract changed
- [ ] New migration added instead of modifying an existing applied migration
- [ ] Screenshots attached for meaningful UI changes
- [ ] Rollout or migration risk documented when relevant
