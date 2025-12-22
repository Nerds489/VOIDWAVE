-- VOIDWAVE Database Schema
-- SQLite with WAL mode for concurrent access

PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA foreign_keys=ON;

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

INSERT INTO schema_version (version, description) VALUES (1, 'Initial schema');

-- Sessions table (replaces ~/.voidwave/sessions/*.session)
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'failed')),
    workflow_state TEXT,  -- State machine state
    config TEXT,          -- JSON serialized session config
    metadata TEXT         -- JSON serialized metadata
);

CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_created ON sessions(created_at);

-- Targets table
CREATE TABLE IF NOT EXISTS targets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('ip', 'cidr', 'hostname', 'url', 'bssid', 'domain')),
    value TEXT NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_scanned TIMESTAMP,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'scanning', 'completed', 'failed')),
    metadata TEXT  -- JSON: open ports, services, OS, etc.
);

CREATE INDEX idx_targets_session ON targets(session_id);
CREATE INDEX idx_targets_type ON targets(target_type);
CREATE UNIQUE INDEX idx_targets_unique ON targets(session_id, target_type, value);

-- Loot table (encrypted credential storage)
CREATE TABLE IF NOT EXISTS loot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL,
    target_id INTEGER REFERENCES targets(id) ON DELETE SET NULL,
    loot_type TEXT NOT NULL CHECK (loot_type IN (
        'credential', 'hash', 'key', 'handshake', 'pmkid',
        'certificate', 'token', 'cookie', 'other'
    )),
    encrypted_data TEXT NOT NULL,  -- Fernet encrypted JSON
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_tool TEXT,
    metadata TEXT  -- JSON: non-sensitive metadata
);

CREATE INDEX idx_loot_session ON loot(session_id);
CREATE INDEX idx_loot_type ON loot(loot_type);

-- Tool executions table
CREATE TABLE IF NOT EXISTS tool_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    tool_name TEXT NOT NULL,
    command TEXT NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    exit_code INTEGER,
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'cancelled', 'timeout')),
    output_file TEXT,  -- Path to full output
    summary TEXT       -- Brief summary/findings
);

CREATE INDEX idx_executions_session ON tool_executions(session_id);
CREATE INDEX idx_executions_tool ON tool_executions(tool_name);

-- Memory table (replaces ~/.voidwave/memory/*.mem)
CREATE TABLE IF NOT EXISTS memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    memory_type TEXT NOT NULL CHECK (memory_type IN ('network', 'host', 'wireless', 'interface', 'wordlist')),
    value TEXT NOT NULL,
    metadata TEXT,  -- JSON
    used_count INTEGER DEFAULT 1,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_memory_type ON memory(memory_type);
CREATE UNIQUE INDEX idx_memory_unique ON memory(memory_type, value);

-- Settings table (for runtime settings that override config file)
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    level TEXT NOT NULL,
    category TEXT,  -- 'tool', 'auth', 'error', 'security'
    message TEXT NOT NULL,
    details TEXT,   -- JSON
    session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL
);

CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_level ON audit_log(level);
CREATE INDEX idx_audit_category ON audit_log(category);

-- Wireless networks table (scan results cache)
CREATE TABLE IF NOT EXISTS wireless_networks (
    bssid TEXT PRIMARY KEY,
    essid TEXT,
    channel INTEGER,
    frequency INTEGER,
    signal_strength INTEGER,
    encryption TEXT,  -- 'open', 'wep', 'wpa', 'wpa2', 'wpa3'
    wps_enabled BOOLEAN DEFAULT FALSE,
    wps_locked BOOLEAN DEFAULT FALSE,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT  -- JSON: vendor, capabilities, etc.
);

CREATE INDEX idx_wireless_essid ON wireless_networks(essid);
CREATE INDEX idx_wireless_encryption ON wireless_networks(encryption);

-- Triggers for updated_at
CREATE TRIGGER update_sessions_timestamp
AFTER UPDATE ON sessions
BEGIN
    UPDATE sessions SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_memory_timestamp
AFTER UPDATE ON memory
BEGIN
    UPDATE memory SET last_used = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
