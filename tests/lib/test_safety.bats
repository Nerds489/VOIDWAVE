#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE lib/safety.sh Unit Tests
# ═══════════════════════════════════════════════════════════════════════════════

setup() {
    load '../test_helper'
    source "$REPO_ROOT/lib/core.sh"
    source "$REPO_ROOT/lib/safety.sh"
}

# ───────────────────────────────────────────────────────────────────────────────
# is_valid_ip tests
# ───────────────────────────────────────────────────────────────────────────────

@test "is_valid_ip accepts valid IPv4" {
    run is_valid_ip "192.168.1.1"
    [[ $status -eq 0 ]]
}

@test "is_valid_ip accepts 10.0.0.1" {
    run is_valid_ip "10.0.0.1"
    [[ $status -eq 0 ]]
}

@test "is_valid_ip accepts 172.16.0.1" {
    run is_valid_ip "172.16.0.1"
    [[ $status -eq 0 ]]
}

@test "is_valid_ip rejects 256.1.1.1" {
    run is_valid_ip "256.1.1.1"
    [[ $status -ne 0 ]]
}

@test "is_valid_ip rejects negative octet" {
    run is_valid_ip "-1.1.1.1"
    [[ $status -ne 0 ]]
}

@test "is_valid_ip rejects empty string" {
    run is_valid_ip ""
    [[ $status -ne 0 ]]
}

@test "is_valid_ip rejects hostname" {
    run is_valid_ip "example.com"
    [[ $status -ne 0 ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# is_private_ip tests
# ───────────────────────────────────────────────────────────────────────────────

@test "is_private_ip detects 192.168.x.x" {
    run is_private_ip "192.168.1.1"
    [[ $status -eq 0 ]]
}

@test "is_private_ip detects 10.x.x.x" {
    run is_private_ip "10.0.0.1"
    [[ $status -eq 0 ]]
}

@test "is_private_ip detects 172.16.x.x" {
    run is_private_ip "172.16.0.1"
    [[ $status -eq 0 ]]
}

@test "is_private_ip detects 172.31.x.x" {
    run is_private_ip "172.31.255.255"
    [[ $status -eq 0 ]]
}

@test "is_private_ip rejects public 8.8.8.8" {
    run is_private_ip "8.8.8.8"
    [[ $status -ne 0 ]]
}

@test "is_private_ip rejects public 1.1.1.1" {
    run is_private_ip "1.1.1.1"
    [[ $status -ne 0 ]]
}

@test "is_private_ip detects localhost 127.0.0.1" {
    run is_private_ip "127.0.0.1"
    [[ $status -eq 0 ]]
}

# ───────────────────────────────────────────────────────────────────────────────
# is_valid_cidr tests
# ───────────────────────────────────────────────────────────────────────────────

@test "is_valid_cidr accepts 192.168.1.0/24" {
    run is_valid_cidr "192.168.1.0/24"
    [[ $status -eq 0 ]]
}

@test "is_valid_cidr accepts 10.0.0.0/8" {
    run is_valid_cidr "10.0.0.0/8"
    [[ $status -eq 0 ]]
}

@test "is_valid_cidr accepts 192.168.1.1/32" {
    run is_valid_cidr "192.168.1.1/32"
    [[ $status -eq 0 ]]
}

@test "is_valid_cidr rejects /33 prefix" {
    run is_valid_cidr "192.168.1.0/33"
    [[ $status -ne 0 ]]
}

@test "is_valid_cidr rejects negative prefix" {
    run is_valid_cidr "192.168.1.0/-1"
    [[ $status -ne 0 ]]
}

@test "is_valid_cidr rejects missing prefix" {
    run is_valid_cidr "192.168.1.0"
    [[ $status -ne 0 ]]
}

@test "is_valid_cidr rejects invalid IP in CIDR" {
    run is_valid_cidr "256.168.1.0/24"
    [[ $status -ne 0 ]]
}
