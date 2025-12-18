# VOIDWAVE Improvement Roadmap

**Document Version:** 1.0
**Date:** 2025-12-15
**Current Version:** 8.0.0 (VOID WAVE)
**Author:** OffTrackMedia Production Engineering

---

## Executive Summary

VOIDWAVE is a mature offensive security framework with 16,733 lines of Bash code across 34+ library files and 8 modules. This roadmap identifies 47 improvement opportunities across 5 categories, prioritized by impact and effort.

**Codebase Health:** Good
**Test Coverage:** Moderate (15 test files, needs expansion)
**Documentation:** Excellent (README, 9 docs files)
**Architecture:** Modular with some technical debt
**CI/CD:** Basic but functional

---

## Table of Contents

1. [Architecture & Code Organization](#1-architecture--code-organization)
2. [CI/CD & Testing](#2-cicd--testing)
3. [Documentation & Help System](#3-documentation--help-system)
4. [Logging & Debugging](#4-logging--debugging)
5. [Configuration Management](#5-configuration-management)
6. [Priority Matrix](#6-priority-matrix)
7. [Implementation Timeline](#7-implementation-timeline)

---

## 1. Architecture & Code Organization

### Quick Wins (Small Effort, High Impact)

#### 1.1 Standardize Error Handling
- **Priority:** P0 (Critical)
- **Effort:** Small (2-4 hours)
- **Impact:** High
- **Description:**
  - Currently mixing `die()`, `log_fatal()`, and direct `exit` calls
  - Inconsistent error codes across modules
  - Missing error handlers in attack modules
- **Action Items:**
  1. Audit all exit points across lib/ and modules/
  2. Replace all `exit` with `die()` or `log_fatal()`
  3. Ensure all functions return proper exit codes
  4. Add error handlers to attack modules (lib/attacks/*.sh)
- **Files Affected:**
  - All lib/attacks/*.sh (8 files)
  - modules/*.sh (8 files)
  - lib/automation/engine.sh
- **Success Criteria:**
  - Zero direct `exit` calls outside main dispatcher
  - All errors logged to audit trail
  - Consistent exit codes

#### 1.2 Remove Duplicate Function Exports
- **Priority:** P2 (Medium)
- **Effort:** Small (1-2 hours)
- **Impact:** Medium
- **Description:**
  - Found 78 `export -f` declarations across library files
  - Many functions exported multiple times
  - Unnecessary exports increase shell environment size
- **Action Items:**
  1. Create single export manifest in lib/core.sh
  2. Remove redundant exports from individual modules
  3. Document exported vs internal functions
- **Files Affected:**
  - All lib/*.sh files
  - Create lib/exports.sh manifest
- **Success Criteria:**
  - Single source of truth for exports
  - Reduced shell environment overhead
  - Clear internal vs public API

#### 1.3 Consolidate Logging Fallbacks
- **Priority:** P2 (Medium)
- **Effort:** Small (2 hours)
- **Impact:** Medium
- **Description:**
  - lib/config.sh has custom logging fallbacks (_config_log_*)
  - lib/menus/settings_menu.sh uses inconsistent logging
  - Creates maintenance burden
- **Action Items:**
  1. Ensure core.sh is sourced first in all modules
  2. Remove custom fallback logging functions
  3. Add pre-flight check in lib loader
- **Files Affected:**
  - lib/config.sh (lines 36-70)
  - lib/wireless_loader.sh
  - All menu files
- **Success Criteria:**
  - Single logging implementation
  - No fallback code duplication

### Medium-Term Improvements (Medium Effort, High Impact)

#### 1.4 Dependency Injection for Tool Paths
- **Priority:** P1 (High)
- **Effort:** Medium (8-12 hours)
- **Impact:** High
- **Description:**
  - Tools hardcoded throughout attack modules
  - No centralized tool path management
  - Difficult to mock for testing
- **Action Items:**
  1. Create lib/tools/registry.sh with tool path mappings
  2. Add get_tool() helper returning path from registry
  3. Refactor attack modules to use registry
  4. Add tool availability cache
- **Files Affected:**
  - Create lib/tools/registry.sh
  - All lib/attacks/*.sh files
  - modules/wireless.sh, modules/exploit.sh
- **Success Criteria:**
  - All tool paths resolved via registry
  - Easy to override paths for testing
  - Tool availability cached per session

#### 1.5 Async Attack Execution Framework
- **Priority:** P1 (High)
- **Effort:** Medium (12-16 hours)
- **Impact:** High
- **Description:**
  - Long-running attacks block UI
  - No background job management
  - Cannot run multiple attacks simultaneously
- **Action Items:**
  1. Create lib/async/executor.sh with job queue
  2. Add process management (start, stop, status, logs)
  3. Build TUI for monitoring background jobs
  4. Add job persistence across sessions
- **Files Affected:**
  - Create lib/async/executor.sh
  - Create lib/async/monitor.sh
  - Modify lib/automation/engine.sh
  - Update lib/wireless/session.sh
- **Success Criteria:**
  - Attacks run in background with live monitoring
  - Job status queryable via CLI/menu
  - Jobs survive session disconnect

#### 1.6 Plugin System for Custom Attacks
- **Priority:** P2 (Medium)
- **Effort:** Large (20-30 hours)
- **Impact:** Medium
- **Description:**
  - Framework lacks extensibility
  - Custom attacks require core modifications
  - No third-party integration mechanism
- **Action Items:**
  1. Design plugin manifest format (YAML/JSON)
  2. Create lib/plugins/loader.sh
  3. Add plugin discovery from ~/.voidwave/plugins/
  4. Build plugin validator and sandbox
  5. Add plugin marketplace integration
- **Files Affected:**
  - Create lib/plugins/* directory
  - Modify lib/menu.sh for dynamic menus
  - Update bin/voidwave dispatcher
- **Success Criteria:**
  - Plugins loaded from user directory
  - Plugins appear in menu system
  - Sandboxed execution environment

### Long-Term Architectural Changes (Large Effort, High Impact)

#### 1.7 Modular Attack Pipelines
- **Priority:** P1 (High)
- **Effort:** Large (40-60 hours)
- **Impact:** Very High
- **Description:**
  - Current attacks are monolithic functions
  - No composability or reusability
  - Difficult to chain attacks or customize flows
- **Action Items:**
  1. Design pipeline DSL (YAML-based)
  2. Break attacks into atomic stages (scan, capture, crack, report)
  3. Create lib/pipeline/engine.sh for orchestration
  4. Build visual pipeline editor (TUI)
  5. Add pipeline templates library
- **Files Affected:**
  - Refactor all lib/attacks/*.sh files
  - Create lib/pipeline/* directory
  - Modify lib/automation/engine.sh
- **Example Pipeline:**
  ```yaml
  name: WPA2 Full Assault
  stages:
    - scan: { duration: 30s, filter: wpa2 }
    - target_selection: { auto: true, criteria: signal_strength }
    - handshake_capture: { timeout: 300s, deauth: smart }
    - crack: { wordlist: rockyou.txt, rules: best64 }
    - report: { format: json, upload: loot }
  ```
- **Success Criteria:**
  - Attacks defined declaratively
  - Stages reusable across pipelines
  - Real-time pipeline monitoring

#### 1.8 Database Backend for Loot Management
- **Priority:** P2 (Medium)
- **Effort:** Large (30-40 hours)
- **Impact:** High
- **Description:**
  - Loot currently stored as flat files
  - No searchability or metadata
  - Difficult to correlate findings across sessions
- **Action Items:**
  1. Choose embedded DB (SQLite preferred)
  2. Design schema (targets, sessions, captures, creds, vulns)
  3. Create lib/db/schema.sql and migration system
  4. Build ORM layer (lib/db/models.sh)
  5. Add search/filter/export CLI
  6. Migrate existing flat files
- **Files Affected:**
  - Create lib/db/* directory
  - Modify lib/wireless/loot.sh
  - Update lib/cracking/cracker.sh
  - Extend bin/voidwave with query commands
- **Success Criteria:**
  - All loot stored in SQLite database
  - Fast search by BSSID, SSID, date, type
  - Export to CSV, JSON, HTML reports
  - Backward compatible with flat file loot

---

## 2. CI/CD & Testing

### Quick Wins

#### 2.1 Add Pre-Commit Hooks
- **Priority:** P1 (High)
- **Effort:** Small (2 hours)
- **Impact:** High
- **Description:**
  - No git hooks to enforce quality
  - Syntax errors reach CI pipeline
- **Action Items:**
  1. Create .git/hooks/pre-commit script
  2. Add shellcheck validation
  3. Add bash -n syntax check
  4. Add smoke tests (--version, --help)
- **Files Affected:**
  - Create .git/hooks/pre-commit
  - Document in CONTRIBUTING.md
- **Success Criteria:**
  - Cannot commit files with syntax errors
  - Shellcheck warnings block commit
  - Fast feedback (<5 seconds)

#### 2.2 Code Coverage Reporting
- **Priority:** P2 (Medium)
- **Effort:** Small (3-4 hours)
- **Impact:** Medium
- **Description:**
  - No visibility into test coverage
  - Unknown which modules are untested
- **Action Items:**
  1. Integrate kcov or bashcov
  2. Add coverage job to .github/workflows/test.yml
  3. Generate HTML coverage reports
  4. Add coverage badge to README
- **Files Affected:**
  - .github/workflows/test.yml
  - Add scripts/generate_coverage.sh
- **Success Criteria:**
  - Coverage tracked per commit
  - HTML report published as artifact
  - Badge shows current coverage percentage

#### 2.3 Expand Smoke Tests
- **Priority:** P1 (High)
- **Effort:** Small (4 hours)
- **Impact:** High
- **Description:**
  - Only 2 smoke tests (help, version)
  - No validation of core commands
- **Action Items:**
  1. Add tests/smoke/test_config.sh
  2. Add tests/smoke/test_status.sh
  3. Add tests/smoke/test_session.sh
  4. Add tests/smoke/test_tools.sh
- **Files Affected:**
  - Create 4 new smoke test files
  - Update .github/workflows/ci.yml
- **Success Criteria:**
  - Core CLI commands validated
  - Runs in <10 seconds
  - Catches dispatcher regressions

### Medium-Term Improvements

#### 2.4 Integration Test Suite
- **Priority:** P1 (High)
- **Effort:** Medium (16-24 hours)
- **Impact:** High
- **Description:**
  - Only 1 integration test file (test_cli.bats)
  - No end-to-end workflow testing
  - Attack modules untested
- **Action Items:**
  1. Create tests/integration/test_wireless_workflow.bats
  2. Create tests/integration/test_attack_chain.bats
  3. Add mock tools for testing (fake aircrack-ng, etc.)
  4. Create test fixtures (sample pcap files)
  5. Add network namespace isolation
- **Files Affected:**
  - Create tests/integration/* files
  - Create tests/fixtures/* directory
  - Add tests/mocks/* for tool stubs
- **Success Criteria:**
  - Full wireless workflow testable
  - Attack chains validated
  - No actual network attacks in tests

#### 2.5 Performance Benchmarking
- **Priority:** P2 (Medium)
- **Effort:** Medium (8-12 hours)
- **Impact:** Medium
- **Description:**
  - No performance metrics
  - Unknown if changes cause regressions
- **Action Items:**
  1. Create benchmarks/suite.sh
  2. Benchmark key operations (scan parse, handshake validation, etc.)
  3. Add benchmark job to CI
  4. Store results as artifacts
  5. Compare against baseline
- **Files Affected:**
  - Create benchmarks/* directory
  - Add .github/workflows/benchmark.yml
- **Success Criteria:**
  - Baseline performance captured
  - Regressions detected in CI
  - Benchmarks run on each release

#### 2.6 Multi-Distro Testing
- **Priority:** P1 (High)
- **Effort:** Medium (12-16 hours)
- **Impact:** High
- **Description:**
  - CI only tests on Ubuntu
  - No validation on Kali, Parrot, Arch, Fedora
- **Action Items:**
  1. Add distro matrix to .github/workflows/test.yml
  2. Test on: Ubuntu, Debian, Kali, Arch, Fedora
  3. Create Docker test containers
  4. Add package installation tests
- **Files Affected:**
  - .github/workflows/test.yml
  - Create tests/docker/* directory
- **Success Criteria:**
  - Tests pass on all supported distros
  - Package installation validated
  - Distro-specific issues caught early

### Long-Term Improvements

#### 2.7 Automated Security Scanning
- **Priority:** P1 (High)
- **Effort:** Large (16-20 hours)
- **Impact:** Very High
- **Description:**
  - No SAST/DAST in pipeline
  - Potential security issues undetected
- **Action Items:**
  1. Integrate shellcheck with security rules
  2. Add bandit-like script analyzer
  3. Add secrets scanning (API keys, passwords)
  4. Add dependency vulnerability scanning
  5. Generate security reports
- **Files Affected:**
  - Create .github/workflows/security.yml
  - Add scripts/security_scan.sh
- **Success Criteria:**
  - Security issues blocked in PR
  - No hardcoded secrets in code
  - Dependency CVEs reported

---

## 3. Documentation & Help System

### Quick Wins

#### 3.1 Function Documentation Headers
- **Priority:** P2 (Medium)
- **Effort:** Small (6-8 hours)
- **Impact:** Medium
- **Description:**
  - Many functions lack documentation
  - No standardized header format
- **Action Items:**
  1. Define standard function header format
  2. Document all exported functions
  3. Add examples in comments
- **Template:**
  ```bash
  #───────────────────────────────────────────────────────────────────────
  # Function: attack_wps_pixie
  # Description: Execute Pixie Dust attack against WPS-enabled AP
  # Args:
  #   $1 - interface (monitor mode)
  #   $2 - target BSSID
  #   $3 - channel
  # Returns: 0 on success, 1 on failure
  # Logs: Success/failure to audit log
  # Example: attack_wps_pixie wlan0mon AA:BB:CC:DD:EE:FF 6
  #───────────────────────────────────────────────────────────────────────
  ```
- **Files Affected:**
  - All lib/*.sh and modules/*.sh files
- **Success Criteria:**
  - All exported functions documented
  - Consistent format across codebase

#### 3.2 Auto-Generate API Reference
- **Priority:** P2 (Medium)
- **Effort:** Small (4-6 hours)
- **Impact:** Medium
- **Description:**
  - No API reference documentation
  - Difficult to find available functions
- **Action Items:**
  1. Create scripts/generate_api_docs.sh
  2. Parse function headers from source
  3. Generate docs/API_REFERENCE.md
  4. Add to CI as validation step
- **Files Affected:**
  - Create scripts/generate_api_docs.sh
  - Generate docs/API_REFERENCE.md
- **Success Criteria:**
  - API docs auto-generated on commit
  - Searchable function reference
  - Examples included

#### 3.3 Interactive Tutorial Mode
- **Priority:** P2 (Medium)
- **Effort:** Small (6-8 hours)
- **Impact:** High
- **Description:**
  - Steep learning curve for new users
  - No guided walkthroughs
- **Action Items:**
  1. Create lib/tutorial.sh
  2. Add `voidwave tutorial <topic>` command
  3. Build step-by-step guides for common workflows
  4. Add practice mode with safe targets
- **Files Affected:**
  - Create lib/tutorial.sh
  - Update bin/voidwave dispatcher
- **Success Criteria:**
  - 5+ interactive tutorials available
  - Tutorials complete in <10 minutes
  - Users can practice safely

### Medium-Term Improvements

#### 3.4 Video Documentation
- **Priority:** P3 (Low)
- **Effort:** Medium (16-20 hours)
- **Impact:** Medium
- **Description:**
  - No video walkthroughs
  - Visual learners underserved
- **Action Items:**
  1. Record screen captures of key workflows
  2. Add voiceover narration
  3. Publish to YouTube/docs site
  4. Embed in README
- **Files Affected:**
  - README.md
  - Create docs/videos/
- **Success Criteria:**
  - 10+ video tutorials
  - Embedded in documentation

#### 3.5 Man Pages
- **Priority:** P2 (Medium)
- **Effort:** Medium (8-12 hours)
- **Impact:** Medium
- **Description:**
  - No man page integration
  - Help only via --help flag
- **Action Items:**
  1. Create man/voidwave.1
  2. Create man/voidwave-install.1
  3. Install to /usr/share/man/man1/
  4. Add section for each subcommand
- **Files Affected:**
  - Create man/* directory
  - Update install.sh
- **Success Criteria:**
  - `man voidwave` works
  - Searchable via apropos

### Long-Term Improvements

#### 3.6 Web-Based Documentation Portal
- **Priority:** P3 (Low)
- **Effort:** Large (40-60 hours)
- **Impact:** Medium
- **Description:**
  - Markdown docs not easily navigable
  - No search functionality
- **Action Items:**
  1. Choose static site generator (MkDocs, Docusaurus)
  2. Convert existing docs to web format
  3. Add search indexing
  4. Deploy to GitHub Pages or dedicated host
  5. Add interactive examples
- **Files Affected:**
  - Create docs-site/* directory
  - Add .github/workflows/deploy-docs.yml
- **Success Criteria:**
  - Live documentation site
  - Full-text search
  - Mobile-responsive

---

## 4. Logging & Debugging

### Quick Wins

#### 4.1 Structured JSON Logging
- **Priority:** P2 (Medium)
- **Effort:** Small (4-6 hours)
- **Impact:** High
- **Description:**
  - Current logs are plain text
  - Difficult to parse programmatically
  - No integration with log aggregators
- **Action Items:**
  1. Add `--log-format json` flag
  2. Extend _log() to support JSON output
  3. Include metadata (timestamp, level, caller, PID)
  4. Maintain backward compatibility
- **Files Affected:**
  - lib/core.sh (logging functions)
  - bin/voidwave (add flag)
- **Success Criteria:**
  - JSON logging available via flag
  - Parseable by jq
  - Compatible with ELK stack

#### 4.2 Debug Shell Command
- **Priority:** P2 (Medium)
- **Effort:** Small (3-4 hours)
- **Impact:** Medium
- **Description:**
  - Difficult to debug issues
  - No interactive shell with context
- **Action Items:**
  1. Add `voidwave debug shell` command
  2. Drop into bash with all libs loaded
  3. Preserve session state
  4. Add helper commands for inspection
- **Files Affected:**
  - bin/voidwave (add debug subcommand)
  - Create lib/debug.sh
- **Success Criteria:**
  - Interactive shell with full context
  - Can inspect variables/functions
  - Useful for troubleshooting

#### 4.3 Log Filtering and Search
- **Priority:** P2 (Medium)
- **Effort:** Small (4 hours)
- **Impact:** Medium
- **Description:**
  - Logs grow large quickly
  - No built-in search capability
- **Action Items:**
  1. Add `voidwave logs search <pattern>` command
  2. Add `voidwave logs filter --level ERROR`
  3. Add `voidwave logs tail --follow`
  4. Add `voidwave logs grep --context 5`
- **Files Affected:**
  - bin/voidwave (add logs subcommand)
  - lib/core.sh (add log utilities)
- **Success Criteria:**
  - Fast log search
  - Filter by level, date, pattern
  - Live tailing with follow

### Medium-Term Improvements

#### 4.4 Performance Profiling
- **Priority:** P2 (Medium)
- **Effort:** Medium (8-12 hours)
- **Impact:** Medium
- **Description:**
  - No visibility into slow operations
  - Cannot identify bottlenecks
- **Action Items:**
  1. Add execution time tracking to all functions
  2. Create profiling mode (`VW_PROFILE=1`)
  3. Generate performance reports
  4. Identify slow paths
- **Files Affected:**
  - lib/core.sh (add timing wrappers)
  - Create lib/profiling.sh
- **Success Criteria:**
  - Per-function timing data
  - Reports show slowest operations
  - Exportable to flamegraph

#### 4.5 Remote Logging
- **Priority:** P3 (Low)
- **Effort:** Medium (12-16 hours)
- **Impact:** Low
- **Description:**
  - No centralized log aggregation
  - Difficult to monitor distributed operations
- **Action Items:**
  1. Add syslog integration
  2. Add remote logging to external services (Splunk, ELK)
  3. Add encryption for log transmission
  4. Configurable via settings
- **Files Affected:**
  - lib/core.sh (add remote logger)
  - lib/menus/settings_menu.sh
- **Success Criteria:**
  - Logs shipped to remote server
  - TLS encryption supported
  - Configurable destinations

### Long-Term Improvements

#### 4.6 Replay and Reproduce Mode
- **Priority:** P2 (Medium)
- **Effort:** Large (20-30 hours)
- **Impact:** High
- **Description:**
  - Cannot reproduce past operations
  - No audit trail for exact commands
- **Action Items:**
  1. Record all user actions to replay log
  2. Add `voidwave replay <session>` command
  3. Support step-through debugging
  4. Export replay scripts
- **Files Affected:**
  - Create lib/replay.sh
  - Modify lib/core.sh for command capture
- **Success Criteria:**
  - Sessions fully reproducible
  - Step-through mode for debugging
  - Export to standalone script

---

## 5. Configuration Management

### Quick Wins

#### 5.1 Environment Variable Documentation
- **Priority:** P2 (Medium)
- **Effort:** Small (2 hours)
- **Impact:** Medium
- **Description:**
  - Environment variables scattered across codebase
  - No central reference
- **Action Items:**
  1. Create docs/ENVIRONMENT_VARIABLES.md
  2. Document all VW_* and VOIDWAVE_* variables
  3. Add examples and defaults
- **Files Affected:**
  - Create docs/ENVIRONMENT_VARIABLES.md
  - Update README.md
- **Success Criteria:**
  - All env vars documented
  - Clear examples provided

#### 5.2 Config Validation
- **Priority:** P1 (High)
- **Effort:** Small (4 hours)
- **Impact:** High
- **Description:**
  - No validation of config file values
  - Invalid config causes silent failures
- **Action Items:**
  1. Add config_validate() function
  2. Validate on load and save
  3. Provide clear error messages
  4. Add `voidwave config validate` command
- **Files Affected:**
  - lib/config.sh
  - bin/voidwave
- **Success Criteria:**
  - Invalid configs rejected
  - Helpful error messages
  - Validation command available

#### 5.3 Config Migration System
- **Priority:** P2 (Medium)
- **Effort:** Small (6 hours)
- **Impact:** Medium
- **Description:**
  - No version tracking in config files
  - Breaking changes affect users
- **Action Items:**
  1. Add version field to config file
  2. Create migration functions for schema changes
  3. Auto-migrate on version mismatch
  4. Backup old config before migration
- **Files Affected:**
  - lib/config.sh
  - Create lib/config/migrations.sh
- **Success Criteria:**
  - Config versions tracked
  - Auto-migration on upgrade
  - Rollback capability

### Medium-Term Improvements

#### 5.4 Profile System
- **Priority:** P2 (Medium)
- **Effort:** Medium (8-12 hours)
- **Impact:** Medium
- **Description:**
  - Cannot save/load different configurations
  - Switching contexts is manual
- **Action Items:**
  1. Add profile support to config system
  2. Create `voidwave profile` subcommands
  3. Store profiles in ~/.voidwave/profiles/
  4. Add profile switching in menu
- **Files Affected:**
  - lib/config.sh
  - Create lib/profiles.sh
  - Update lib/menu.sh
- **Success Criteria:**
  - Multiple profiles supported
  - Fast profile switching
  - Per-profile settings isolated

#### 5.5 Config Templates
- **Priority:** P3 (Low)
- **Effort:** Medium (6-8 hours)
- **Impact:** Low
- **Description:**
  - No quick-start templates
  - Users must configure from scratch
- **Action Items:**
  1. Create template configs for common scenarios
  2. Add `voidwave config from-template <name>`
  3. Include: pentest, ctf, training, stealth
- **Files Affected:**
  - Create data/config-templates/
  - lib/config.sh
- **Success Criteria:**
  - 5+ templates available
  - One-command setup

### Long-Term Improvements

#### 5.6 GUI Configuration Editor
- **Priority:** P3 (Low)
- **Effort:** Large (30-40 hours)
- **Impact:** Low
- **Description:**
  - CLI-only configuration
  - No visual editor
- **Action Items:**
  1. Choose TUI framework (dialog, whiptail, or custom)
  2. Build visual config editor
  3. Add validation and help text
  4. Support all config options
- **Files Affected:**
  - Create lib/ui/config_editor.sh
  - Integrate into main menu
- **Success Criteria:**
  - Visual config editor
  - Real-time validation
  - Help text for all options

---

## 6. Priority Matrix

### P0 - Critical (Must Fix Immediately)

| Item | Category | Effort | Impact | ETA |
|------|----------|--------|--------|-----|
| 1.1 Standardize Error Handling | Architecture | Small | High | 1 week |

### P1 - High Priority (Next Sprint)

| Item | Category | Effort | Impact | ETA |
|------|----------|--------|--------|-----|
| 1.4 Dependency Injection | Architecture | Medium | High | 2 weeks |
| 1.5 Async Attack Execution | Architecture | Medium | High | 3 weeks |
| 1.7 Modular Attack Pipelines | Architecture | Large | Very High | 8 weeks |
| 2.1 Pre-Commit Hooks | CI/CD | Small | High | 1 week |
| 2.3 Expand Smoke Tests | CI/CD | Small | High | 1 week |
| 2.4 Integration Test Suite | CI/CD | Medium | High | 3 weeks |
| 2.6 Multi-Distro Testing | CI/CD | Medium | High | 2 weeks |
| 2.7 Automated Security Scanning | CI/CD | Large | Very High | 3 weeks |
| 5.2 Config Validation | Configuration | Small | High | 1 week |

### P2 - Medium Priority (Next Quarter)

| Item | Category | Effort | Impact | ETA |
|------|----------|--------|--------|-----|
| 1.2 Remove Duplicate Exports | Architecture | Small | Medium | 1 week |
| 1.3 Consolidate Logging | Architecture | Small | Medium | 1 week |
| 1.6 Plugin System | Architecture | Large | Medium | 6 weeks |
| 1.8 Database Backend | Architecture | Large | High | 6 weeks |
| 2.2 Code Coverage | CI/CD | Small | Medium | 1 week |
| 2.5 Performance Benchmarking | CI/CD | Medium | Medium | 2 weeks |
| 3.1 Function Documentation | Documentation | Small | Medium | 2 weeks |
| 3.2 Auto-Generate API Docs | Documentation | Small | Medium | 1 week |
| 3.3 Interactive Tutorials | Documentation | Small | High | 2 weeks |
| 3.5 Man Pages | Documentation | Medium | Medium | 2 weeks |
| 4.1 Structured JSON Logging | Logging | Small | High | 1 week |
| 4.2 Debug Shell | Logging | Small | Medium | 1 week |
| 4.3 Log Search | Logging | Small | Medium | 1 week |
| 4.4 Performance Profiling | Logging | Medium | Medium | 2 weeks |
| 4.6 Replay Mode | Logging | Large | High | 4 weeks |
| 5.1 Env Var Documentation | Configuration | Small | Medium | 1 day |
| 5.3 Config Migration | Configuration | Small | Medium | 1 week |
| 5.4 Profile System | Configuration | Medium | Medium | 2 weeks |

### P3 - Low Priority (Backlog)

| Item | Category | Effort | Impact | ETA |
|------|----------|--------|--------|-----|
| 3.4 Video Documentation | Documentation | Medium | Medium | 4 weeks |
| 3.6 Web Documentation Portal | Documentation | Large | Medium | 8 weeks |
| 4.5 Remote Logging | Logging | Medium | Low | 3 weeks |
| 5.5 Config Templates | Configuration | Medium | Low | 2 weeks |
| 5.6 GUI Config Editor | Configuration | Large | Low | 6 weeks |

---

## 7. Implementation Timeline

### Phase 1: Foundation (Weeks 1-4)

**Focus:** Critical fixes and quick wins

1. Week 1:
   - 1.1 Standardize Error Handling
   - 2.1 Pre-Commit Hooks
   - 2.3 Expand Smoke Tests
   - 5.1 Env Var Documentation
   - 5.2 Config Validation

2. Week 2:
   - 1.2 Remove Duplicate Exports
   - 1.3 Consolidate Logging
   - 2.2 Code Coverage
   - 4.1 Structured JSON Logging

3. Week 3-4:
   - 1.4 Dependency Injection
   - 2.6 Multi-Distro Testing
   - 3.1 Function Documentation (start)

**Deliverable:** Stable foundation with 90% test pass rate

### Phase 2: Enhancement (Weeks 5-12)

**Focus:** Medium-term improvements

1. Weeks 5-7:
   - 1.5 Async Attack Execution
   - 2.4 Integration Test Suite
   - 2.7 Automated Security Scanning

2. Weeks 8-10:
   - 1.8 Database Backend
   - 3.2 Auto-Generate API Docs
   - 3.3 Interactive Tutorials

3. Weeks 11-12:
   - 4.4 Performance Profiling
   - 5.4 Profile System
   - Complete 3.1 Function Documentation

**Deliverable:** Enhanced feature set with improved UX

### Phase 3: Transformation (Weeks 13-20)

**Focus:** Long-term architectural changes

1. Weeks 13-20:
   - 1.7 Modular Attack Pipelines (primary focus)
   - 1.6 Plugin System
   - 4.6 Replay Mode
   - 3.6 Web Documentation Portal (if time permits)

**Deliverable:** Next-generation architecture

---

## Success Metrics

### Code Quality
- ShellCheck issues: < 10 (currently unknown)
- Function documentation coverage: > 90% (currently ~30%)
- Test coverage: > 70% (currently ~40% estimated)

### Performance
- Attack startup time: < 5 seconds
- Menu responsiveness: < 100ms
- Log search: < 1 second for 1M lines

### User Experience
- Time to first successful attack: < 15 minutes
- Tutorial completion rate: > 80%
- Support ticket reduction: > 50%

### Reliability
- CI pass rate: > 98%
- Multi-distro support: 5+ distros tested
- Critical bugs per release: < 5

---

## Appendix A: Technical Debt Register

### Current Issues Identified

1. **Inconsistent sourcing order** - 21 of 34 lib files source core.sh, others rely on dispatcher
2. **No TODO/FIXME markers** - Clean codebase, but no explicit debt tracking
3. **78 function exports** - Likely over-exporting, needs audit
4. **Settings menu sources config unsafely** - Line 422 uses `source` on user config (security risk)
5. **Log rotation not automated** - Manual rotation only, needs cron/systemd timer
6. **No log size limits** - Files can grow unbounded
7. **Error handler recursion protection** - Good, but could be more robust
8. **VIF whitelist hardcoded** - Should be data-driven from file
9. **No versioned API** - Function signatures can change without notice
10. **Session file format undocumented** - Makes parsing difficult

---

## Appendix B: Recommended Tools

### Development
- **ShellCheck** - Linting (already in use)
- **shfmt** - Code formatting
- **bashcov/kcov** - Coverage tracking
- **shellspec** - BDD testing framework (consider migration from bats)

### CI/CD
- **act** - Local GitHub Actions testing
- **hadolint** - Dockerfile linting (for future containerization)
- **trivy** - Security scanning

### Documentation
- **shdoc** - Auto-generate docs from comments
- **MkDocs** - Static site generator
- **asciinema** - Terminal recording

### Monitoring
- **Prometheus node_exporter** - Metrics collection
- **Grafana** - Visualization
- **Loki** - Log aggregation

---

## Appendix C: Migration Checklist

When implementing improvements, follow this checklist:

- [ ] Create feature branch from `main`
- [ ] Update CHANGELOG.md with changes
- [ ] Add/update tests for new functionality
- [ ] Update documentation (README, man pages, API docs)
- [ ] Run full test suite locally
- [ ] Verify on multiple distros (Docker)
- [ ] Run security scan
- [ ] Update VERSION file if needed
- [ ] Create PR with detailed description
- [ ] Request review from maintainers
- [ ] Address review feedback
- [ ] Squash commits before merge
- [ ] Tag release if appropriate

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-15 | Production Engineer | Initial roadmap |

---

**End of Document**
