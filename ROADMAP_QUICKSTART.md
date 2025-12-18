# VOIDWAVE Improvement Roadmap - Quick Start Guide

**Ready to improve? Start here.**

---

## TL;DR - First Week Action Items

Execute these 5 tasks in order for maximum impact with minimum effort:

### 1. Standardize Error Handling (Day 1-2)
**Time:** 4 hours | **Impact:** Critical

```bash
# Find all direct exit calls
grep -rn "exit [0-9]" lib/ modules/ --exclude-dir=.git

# Replace with:
die "Error message" $EXIT_CODE_FAILURE

# Ensure all functions return codes:
# 0 = success, 1 = failure, 2 = invalid args, etc.
```

**Files to fix:**
- All `lib/attacks/*.sh` (8 files)
- `lib/automation/engine.sh`
- All `modules/*.sh` (8 files)

**Validation:**
```bash
# No direct exits outside bin/voidwave
! grep -r "^\s*exit [0-9]" lib/ modules/ || echo "FAIL: Found direct exit calls"
```

---

### 2. Add Pre-Commit Hooks (Day 2)
**Time:** 2 hours | **Impact:** High

```bash
# Create hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running pre-commit checks..."

# Syntax check
for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do
    bash -n "$f" || exit 1
done

# ShellCheck (errors only)
shellcheck --severity=error $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$') || exit 1

# Smoke tests
./tests/smoke/test_help.sh || exit 1
./tests/smoke/test_version.sh || exit 1

echo "All checks passed!"
EOF

chmod +x .git/hooks/pre-commit
```

**Test:**
```bash
# Try to commit a file with syntax error
echo "function bad( {" > test_bad.sh
git add test_bad.sh
git commit -m "test"  # Should fail
```

---

### 3. Expand Smoke Tests (Day 3)
**Time:** 4 hours | **Impact:** High

Create these 4 new test files:

**tests/smoke/test_config.sh:**
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1

./bin/voidwave config show > /dev/null
./bin/voidwave config get log_level > /dev/null
./bin/voidwave config path > /dev/null

echo "✓ Config smoke tests passed"
```

**tests/smoke/test_status.sh:**
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1

./bin/voidwave status > /dev/null

echo "✓ Status smoke test passed"
```

**tests/smoke/test_session.sh:**
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1

# Session operations
./bin/voidwave session list > /dev/null

echo "✓ Session smoke tests passed"
```

**tests/smoke/test_tools.sh:**
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/../.."

# Verify core binaries exist
command -v voidwave >/dev/null
command -v voidwave-install >/dev/null

echo "✓ Tool smoke tests passed"
```

Make executable:
```bash
chmod +x tests/smoke/test_*.sh
```

Update `.github/workflows/ci.yml`:
```yaml
- name: Smoke tests
  run: |
    chmod +x tests/smoke/*.sh
    for test in tests/smoke/*.sh; do
      echo "Running $test..."
      $test
    done
```

---

### 4. Document Environment Variables (Day 3)
**Time:** 2 hours | **Impact:** Medium

Create **docs/ENVIRONMENT_VARIABLES.md**:

```markdown
# VOIDWAVE Environment Variables

## Core Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `VOIDWAVE_HOME` | Path | `~/.voidwave` | Base directory for all data |
| `VOIDWAVE_LOG_DIR` | Path | `~/.voidwave/logs` | Log file location |
| `VOIDWAVE_LOG_LEVEL` | 0-5 | `1` (INFO) | Minimum log level (0=DEBUG, 5=FATAL) |
| `VOIDWAVE_FILE_LOGGING` | 0/1 | `1` | Enable file logging |
| `VW_NON_INTERACTIVE` | 0/1 | `0` | Skip interactive prompts |
| `VW_UNSAFE_MODE` | 0/1 | `0` | Bypass safety checks (DANGEROUS) |
| `VW_DRY_RUN` | 0/1 | `0` | Preview mode - show commands without executing |
| `VW_SUPPRESS_OUTPUT` | 0/1 | `0` | Silent mode for CI/testing |

## API Keys

| Variable | Description |
|----------|-------------|
| `SHODAN_API_KEY` | Shodan.io API key for OSINT |
| `VT_API_KEY` | VirusTotal API key |
| `CENSYS_API_KEY` | Censys.io API key |
| `HUNTER_API_KEY` | Hunter.io email search |

## Advanced Settings

| Variable | Description |
|----------|-------------|
| `CRACK_USE_GPU` | Enable GPU acceleration for hashcat |
| `AUTO_ATTACK_CHAIN` | Array of attacks for pillage mode |

## Examples

**Run in non-interactive CI mode:**
```bash
VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1 voidwave config show
```

**Dry-run to preview commands:**
```bash
VW_DRY_RUN=1 voidwave wifi scan
```

**Verbose debug logging:**
```bash
VOIDWAVE_LOG_LEVEL=0 DEBUG=true voidwave status
```
```

Add reference to README.md:
```markdown
## Configuration

See [Environment Variables](docs/ENVIRONMENT_VARIABLES.md) for full list.
```

---

### 5. Add Config Validation (Day 4)
**Time:** 4 hours | **Impact:** High

Edit **lib/config.sh**, add after line 100:

```bash
#═══════════════════════════════════════════════════════════════════════════════
# CONFIG VALIDATION
#═══════════════════════════════════════════════════════════════════════════════

# Validate a single config key/value
# Args: $1 = key, $2 = value
# Returns: 0 if valid, 1 if invalid
validate_config_value() {
    local key="$1"
    local value="$2"

    case "$key" in
        log_level)
            # Must be DEBUG, INFO, SUCCESS, WARNING, ERROR, or FATAL
            if [[ ! "$value" =~ ^(DEBUG|INFO|SUCCESS|WARNING|ERROR|FATAL)$ ]]; then
                _config_log_error "Invalid log_level: $value (must be DEBUG, INFO, SUCCESS, WARNING, ERROR, FATAL)"
                return 1
            fi
            ;;
        file_logging)
            # Must be true or false
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                _config_log_error "Invalid file_logging: $value (must be true or false)"
                return 1
            fi
            ;;
        default_scan_type)
            # Must be standard, quick, full, stealth, udp, vuln, service, os
            if [[ ! "$value" =~ ^(standard|quick|full|stealth|udp|vuln|service|os)$ ]]; then
                _config_log_error "Invalid default_scan_type: $value"
                return 1
            fi
            ;;
        confirm_dangerous|warn_public_ip|unsafe_mode)
            # Boolean values
            if [[ ! "$value" =~ ^(true|false)$ ]]; then
                _config_log_error "Invalid boolean value for $key: $value"
                return 1
            fi
            ;;
        default_wordlist)
            # Path must exist if set to non-default
            if [[ "$value" != "/usr/share/wordlists/rockyou.txt" ]] && [[ ! -f "$value" ]]; then
                _config_log_error "Wordlist not found: $value"
                return 1
            fi
            ;;
        non_interactive_default_index)
            # Must be integer >= 0
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                _config_log_error "Invalid non_interactive_default_index: $value (must be integer >= 0)"
                return 1
            fi
            ;;
        *)
            # Unknown keys allowed (for extensibility)
            _config_log_debug "Unknown config key: $key (allowing)"
            ;;
    esac

    return 0
}

# Validate entire config file
# Returns: 0 if valid, 1 if any errors
validate_config() {
    local config_file="${VOIDWAVE_CONFIG_FILE}"
    local errors=0

    if [[ ! -f "$config_file" ]]; then
        _config_log_error "Config file not found: $config_file"
        return 1
    fi

    _config_log_info "Validating config: $config_file"

    # Parse and validate each line
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" == \#* ]] && continue

        # Remove quotes from value
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"

        # Validate
        if ! validate_config_value "$key" "$value"; then
            ((errors++))
        fi
    done < "$config_file"

    if [[ $errors -gt 0 ]]; then
        _config_log_error "Config validation failed with $errors error(s)"
        return 1
    fi

    _config_log_success "Config validation passed"
    return 0
}

export -f validate_config_value validate_config
```

Add CLI command in **bin/voidwave**, in the config subcommand section:

```bash
        validate)
            load_config_lib
            validate_config
            ;;
```

**Test:**
```bash
# Valid config
voidwave config set log_level INFO
voidwave config validate  # Should pass

# Invalid config
voidwave config set log_level INVALID
voidwave config validate  # Should fail with error

# Fix it
voidwave config set log_level WARNING
voidwave config validate  # Should pass
```

---

## Verification Commands

After completing the 5 tasks, run these to verify:

```bash
# 1. Error handling check
! grep -r "^\s*exit [0-9]" lib/ modules/ && echo "✓ No direct exits"

# 2. Pre-commit hook
ls -l .git/hooks/pre-commit && echo "✓ Hook installed"

# 3. Smoke tests
for t in tests/smoke/*.sh; do $t && echo "✓ $(basename $t)"; done

# 4. Environment docs
test -f docs/ENVIRONMENT_VARIABLES.md && echo "✓ Env docs exist"

# 5. Config validation
voidwave config validate && echo "✓ Config valid"
```

---

## Next Steps (Week 2)

After completing Week 1, tackle these in Week 2:

1. **Remove Duplicate Exports** (Day 5-6)
   - Audit all `export -f` statements
   - Create single export manifest
   - Test all functionality

2. **Consolidate Logging Fallbacks** (Day 6)
   - Remove custom logging from lib/config.sh
   - Ensure core.sh sourced first everywhere

3. **Code Coverage** (Day 7)
   - Install kcov or bashcov
   - Add to CI pipeline
   - Generate baseline report

4. **Structured JSON Logging** (Day 8-9)
   - Add --log-format json flag
   - Extend _log() function
   - Test with jq

5. **Debug Shell** (Day 9-10)
   - Add voidwave debug shell command
   - Load all libs in context
   - Test interactive debugging

---

## Quick Reference

### File Locations
- Main roadmap: `/home/minty/NETREAPER/IMPROVEMENT_ROADMAP.md`
- This quickstart: `/home/minty/NETREAPER/ROADMAP_QUICKSTART.md`
- Tests: `/home/minty/NETREAPER/tests/`
- Docs: `/home/minty/NETREAPER/docs/`
- CI: `/home/minty/NETREAPER/.github/workflows/`

### Key Commands
```bash
# Run all tests
bats tests/*.bats

# Run smoke tests
tests/smoke/test_help.sh
tests/smoke/test_version.sh

# Check syntax
bash -n lib/*.sh modules/*.sh

# ShellCheck
shellcheck --severity=error lib/*.sh modules/*.sh

# View logs
tail -f ~/.voidwave/logs/voidwave_$(date +%Y%m%d).log

# Validate config
voidwave config validate
```

### Useful Aliases
Add to your ~/.bashrc:

```bash
alias vw='voidwave'
alias vwl='tail -f ~/.voidwave/logs/voidwave_$(date +%Y%m%d).log'
alias vwt='bats tests/*.bats'
alias vws='tests/smoke/*.sh'
alias vwc='voidwave config'
```

---

## Getting Help

- Main roadmap: Read `IMPROVEMENT_ROADMAP.md` for detailed plans
- Documentation: Check `docs/` directory

---

**Ready? Start with Task 1: Standardize Error Handling**

The first week of improvements will give you:
- Consistent error handling across entire codebase
- Automated quality gates preventing bad commits
- Expanded test coverage catching regressions
- Better documentation for users and developers
- Validated configuration preventing silent failures

Each task builds on the previous one. Follow the order for maximum efficiency.

**Time Investment:** ~20 hours over 4 days
**Impact:** Foundation for all future improvements

Let's make VOIDWAVE bulletproof!
