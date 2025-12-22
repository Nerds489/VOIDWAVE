#!/bin/bash
# Validate TUI implementation structure

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        VOIDWAVE TUI Layer - Structure Validation              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

TUI_DIR="/var/home/mintys/Desktop/VOIDWAVE/src/voidwave/tui"

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check main files
echo -e "${CYAN}[1] Core TUI Files${NC}"
for file in "__init__.py" "app.py" "theme.py" "cyberpunk.tcss"; do
    if [ -f "$TUI_DIR/$file" ]; then
        lines=$(wc -l < "$TUI_DIR/$file")
        echo -e "  ${GREEN}✓${NC} $file ($lines lines)"
    else
        echo -e "  ${YELLOW}✗${NC} $file (missing)"
    fi
done
echo

# Check screens
echo -e "${CYAN}[2] Screen Modules${NC}"
SCREENS=(
    "main.py" "wireless.py" "scan.py" "credentials.py"
    "osint.py" "recon.py" "traffic.py" "exploit.py"
    "stress.py" "status.py" "settings.py" "help.py"
)
for screen in "${SCREENS[@]}"; do
    if [ -f "$TUI_DIR/screens/$screen" ]; then
        lines=$(wc -l < "$TUI_DIR/screens/$screen")
        echo -e "  ${GREEN}✓${NC} screens/$screen ($lines lines)"
    else
        echo -e "  ${YELLOW}✗${NC} screens/$screen (missing)"
    fi
done
echo

# Check widgets
echo -e "${CYAN}[3] Widget Components${NC}"
WIDGETS=(
    "tool_output.py" "status_panel.py"
    "target_tree.py" "progress_panel.py"
)
for widget in "${WIDGETS[@]}"; do
    if [ -f "$TUI_DIR/widgets/$widget" ]; then
        lines=$(wc -l < "$TUI_DIR/widgets/$widget")
        echo -e "  ${GREEN}✓${NC} widgets/$widget ($lines lines)"
    else
        echo -e "  ${YELLOW}✗${NC} widgets/$widget (missing)"
    fi
done
echo

# Check wizards
echo -e "${CYAN}[4] Wizard Modules${NC}"
WIZARDS=("first_run.py" "scan_wizard.py")
for wizard in "${WIZARDS[@]}"; do
    if [ -f "$TUI_DIR/wizards/$wizard" ]; then
        lines=$(wc -l < "$TUI_DIR/wizards/$wizard")
        echo -e "  ${GREEN}✓${NC} wizards/$wizard ($lines lines)"
    else
        echo -e "  ${YELLOW}✗${NC} wizards/$wizard (missing)"
    fi
done
echo

# Check commands
echo -e "${CYAN}[5] Command Palette${NC}"
for file in "__init__.py" "tools.py"; do
    if [ -f "$TUI_DIR/commands/$file" ]; then
        lines=$(wc -l < "$TUI_DIR/commands/$file")
        echo -e "  ${GREEN}✓${NC} commands/$file ($lines lines)"
    else
        echo -e "  ${YELLOW}✗${NC} commands/$file (missing)"
    fi
done
echo

# Summary
echo -e "${CYAN}[6] Summary Statistics${NC}"
total_py=$(find "$TUI_DIR" -name "*.py" | wc -l)
total_lines=$(find "$TUI_DIR" -name "*.py" -exec wc -l {} + | tail -1 | awk '{print $1}')
css_lines=$(wc -l < "$TUI_DIR/cyberpunk.tcss" 2>/dev/null || echo 0)

echo -e "  • Python files: ${GREEN}$total_py${NC}"
echo -e "  • Python lines: ${GREEN}$total_lines${NC}"
echo -e "  • CSS lines: ${GREEN}$css_lines${NC}"
echo -e "  • Total lines: ${GREEN}$((total_lines + css_lines))${NC}"
echo

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Validation Complete ✓                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
