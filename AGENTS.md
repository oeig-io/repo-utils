# AGENTS.md

Guidelines for AI agents working in this repository.

If someone asks your name, your nickname is Fred.

## Repo Orientation

| Directory | Purpose |
|-----------|---------|
| `container-management/` | Create/manage NixOS incus containers |
| `idempiere-golive-deploy/` | Deploy configuration to iDempiere containers |
| `install-idempiere/` | iDempiere installer (NixOS + Ansible) |
| `wi-*/` | Work instruction documentation |
| `corporate/` | Internal company documentation |

## Common Workflows

### Create new iDempiere container with deployment

```bash
# 1. Create container (runs install.sh inside)
cd container-management && ./launch.sh configs/idempiere.conf id-01

# 2. Verify service is ready (HTTP 405 = ready)
incus exec id-01 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/auth/tokens

# 3. Run deployment (10 minute timeout)
cd idempiere-golive-deploy && ./deploy.sh id-01
```

### Verify deployment completion

```bash
# Check tenant was created
incus exec id-01 -- su - idempiere -c "psqli -c \"SELECT name, value FROM adempiere.ad_client WHERE ad_client_id = 1000000;\""

# Check users exist
incus exec id-01 -- su - idempiere -c "psqli -c \"SELECT name, email FROM adempiere.ad_user WHERE name LIKE 'Bearly%';\""
```

### Verify container status before taking action

```bash
# Check if container exists and is running
incus list id-01 --format csv -c n,s

# Check if service is already ready (don't re-run deploy if complete)
incus exec id-01 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/auth/tokens
```

## Mistakes to Avoid

### Don't re-run completed commands

If a long-running command (like deploy.sh) appears to complete, verify the result before running again. Check:
- Audit log for START/STOP pairs
- Database for expected records
- Service health endpoint

### Don't assume timeout means failure

A command that times out may have actually completed. Always verify actual state:
- Check container is still running
- Query database for expected data
- Check service health

### Confirm before destructive operations

Before:
- Deleting containers (`incus delete`)
- Resetting databases (`reset.sh`)
- Rebuilding systems (`nixos-rebuild`)

Verify with user explicitly.

## My Preferences

### Code and file standards

- Follow `wi-base/WORK_INSTRUCTIONS.md` for documentation
- Use YAML frontmatter for tool files (see WORK_INSTRUCTIONS.md section on Tool Frontmatter Standards)
- Keep files lowercase with dashes: `my-file-name.md`

### Timeout guidelines

| Command type | Typical timeout |
|--------------|-----------------|
| Container creation | 10 minutes |
| Full deployment | 10 minutes |
| Single deploy script | 2 minutes |
| Database queries | 30 seconds |

## Useful Commands

```bash
# List all id-* containers
incus list --format csv -c n | grep '^id-'

# Check container health
incus exec <container> -- curl -s http://localhost:8080/api/v1/auth/tokens

# Get container IP
incus list <container> -c 4

# Execute as idempiere user
incus exec <container> -- su - idempiere -c "<command>"
```
