#!/bin/bash
# Check K3s prerequisites on Raspberry Pi
set -e

# Parse input parameters
eval "$(jq -r '@sh "DEBUG=\(.debug)"')"

if [ "$DEBUG" = "true" ]; then
    set -x
fi

# Initialize result
STATUS="ready"
CHECKS=()
WARNINGS=()
ERRORS=()

# Function to add check result
add_check() {
    local check_name="$1"
    local check_status="$2"
    local check_message="$3"
    
    CHECKS+=("{\"name\":\"$check_name\",\"status\":\"$check_status\",\"message\":\"$check_message\"}")
    
    if [ "$check_status" = "failed" ]; then
        STATUS="failed"
        ERRORS+=("$check_message")
    elif [ "$check_status" = "warning" ]; then
        WARNINGS+=("$check_message")
    fi
}

# Check 1: Operating System
if [ -f /etc/os-release ]; then
    OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    
    if [[ "$OS_ID" =~ ^(ubuntu|debian|raspios)$ ]]; then
        add_check "operating_system" "passed" "Compatible OS: $OS_ID $OS_VERSION"
    else
        add_check "operating_system" "warning" "Untested OS: $OS_ID $OS_VERSION"
    fi
else
    add_check "operating_system" "failed" "Cannot determine operating system"
fi

# Check 2: Architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    add_check "architecture" "passed" "ARM64 architecture detected"
elif [ "$ARCH" = "x86_64" ]; then
    add_check "architecture" "passed" "x86_64 architecture detected"
else
    add_check "architecture" "warning" "Untested architecture: $ARCH"
fi

# Check 3: Memory
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_GB=$(( MEMORY_KB / 1024 / 1024 ))

if [ $MEMORY_GB -ge 4 ]; then
    add_check "memory" "passed" "${MEMORY_GB}GB RAM available"
elif [ $MEMORY_GB -ge 2 ]; then
    add_check "memory" "warning" "Only ${MEMORY_GB}GB RAM available (4GB+ recommended)"
else
    add_check "memory" "failed" "Insufficient RAM: ${MEMORY_GB}GB (minimum 2GB required)"
fi

# Check 4: Disk Space
ROOT_AVAIL=$(df / | tail -1 | awk '{print $4}')
ROOT_AVAIL_GB=$(( ROOT_AVAIL / 1024 / 1024 ))

if [ $ROOT_AVAIL_GB -ge 20 ]; then
    add_check "disk_space" "passed" "${ROOT_AVAIL_GB}GB available on root filesystem"
elif [ $ROOT_AVAIL_GB -ge 10 ]; then
    add_check "disk_space" "warning" "Only ${ROOT_AVAIL_GB}GB available (20GB+ recommended)"
else
    add_check "disk_space" "failed" "Insufficient disk space: ${ROOT_AVAIL_GB}GB (minimum 10GB required)"
fi

# Check 5: Network connectivity
if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    add_check "internet_connectivity" "passed" "Internet connectivity verified"
else
    add_check "internet_connectivity" "failed" "No internet connectivity"
fi

# Check 6: Required commands
REQUIRED_COMMANDS=("curl" "iptables" "mount")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" > /dev/null 2>&1; then
        add_check "command_$cmd" "passed" "$cmd command available"
    else
        add_check "command_$cmd" "failed" "$cmd command not found"
    fi
done

# Check 7: Kernel modules and features
REQUIRED_MODULES=("overlay" "br_netfilter")
for module in "${REQUIRED_MODULES[@]}"; do
    if lsmod | grep -q "^$module"; then
        add_check "module_$module" "passed" "$module module loaded"
    elif modprobe "$module" 2>/dev/null; then
        add_check "module_$module" "passed" "$module module loaded successfully"
    else
        add_check "module_$module" "warning" "$module module not available"
    fi
done

# Check 8: cgroups v2
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    add_check "cgroups_v2" "passed" "cgroups v2 available"
else
    add_check "cgroups_v2" "warning" "cgroups v2 not detected"
fi

# Check 9: Systemd
if systemctl --version > /dev/null 2>&1; then
    add_check "systemd" "passed" "systemd available"
else
    add_check "systemd" "failed" "systemd not available"
fi

# Check 10: Firewall status
if systemctl is-active --quiet ufw; then
    add_check "firewall" "warning" "UFW firewall is active (may need configuration)"
elif systemctl is-active --quiet firewalld; then
    add_check "firewall" "warning" "firewalld is active (may need configuration)"
else
    add_check "firewall" "passed" "No active firewall detected"
fi

# Generate JSON output
CHECKS_JSON=$(IFS=','; echo "${CHECKS[*]}")

jq -n \
  --arg status "$STATUS" \
  --argjson checks "[$CHECKS_JSON]" \
  --argjson warnings "$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)" \
  --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
  '{
    status: $status,
    checks: $checks,
    warnings: $warnings,
    errors: $errors,
    timestamp: now | strftime("%Y-%m-%d %H:%M:%S UTC")
  }'
