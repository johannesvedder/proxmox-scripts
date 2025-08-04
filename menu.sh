#!/bin/bash

# Interactive menu for proxmox scripts
# Navigate with arrow keys, expand directories with Enter/Space, execute files with Enter

# Terminal colors and control sequences
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Terminal control
CLEAR_LINE='\033[2K'
MOVE_UP='\033[1A'
MOVE_DOWN='\033[1B'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'

# Global variables
REPO_DIR="${ROOT_DIR:-$(dirname "$0")}/repository"
current_selection=0
menu_items=()
item_types=()
item_paths=()
expanded_dirs=()

# Check if directory is expanded
is_expanded() {
    local dir="$1"
    for expanded in "${expanded_dirs[@]}"; do
        if [[ "$expanded" == "$dir" ]]; then
            return 0
        fi
    done
    return 1
}

# Toggle directory expansion
toggle_expansion() {
    local dir="$1"
    local found=0
    local new_expanded=()

    for expanded in "${expanded_dirs[@]}"; do
        if [[ "$expanded" == "$dir" ]]; then
            found=1
        else
            new_expanded+=("$expanded")
        fi
    done

    if [[ $found -eq 0 ]]; then
        expanded_dirs+=("$dir")
    else
        expanded_dirs=("${new_expanded[@]}")
    fi
}

# Build menu items recursively
build_menu() {
    local base_dir="$1"
    local prefix="$2"
    local current_dir="${base_dir#$REPO_DIR/}"
    [[ "$current_dir" == "$REPO_DIR" ]] && current_dir=""

    # Add current directory items
    if [[ -d "$base_dir" ]]; then
        for item in "$base_dir"/*; do
            [[ ! -e "$item" ]] && continue

            local basename=$(basename "$item")
            local relative_path="${item#$REPO_DIR/}"

            if [[ -d "$item" ]]; then
                # Special handling for apps directory
                if [[ "$relative_path" == "apps" ]]; then
                    # Show apps directory as expandable
                    menu_items+=("${prefix}🧩 $basename/")
                    item_types+=("dir")
                    item_paths+=("$relative_path")

                    # If expanded, show app folders as executable items
                    if is_expanded "$relative_path"; then
                        for app_dir in "$item"/*; do
                            if [[ -d "$app_dir" && -f "$app_dir/main.sh" ]]; then
                                local app_name=$(basename "$app_dir")
                                menu_items+=("${prefix}  🚀 $app_name")
                                item_types+=("app")
                                item_paths+=("apps/$app_name")
                            fi
                        done
                    fi
                # Special handling for apps subdirectories when viewing them directly
                elif [[ "$relative_path" == apps/* && -f "$item/main.sh" ]]; then
                    # This is an app directory with main.sh - make it executable
                    menu_items+=("${prefix}🚀 $basename")
                    item_types+=("app")
                    item_paths+=("$relative_path")
                else
                    # Regular directory
                    # todo use this for regular dirs: 📁 and 🗂️ for scripts
                    menu_items+=("${prefix}🗂️ $basename/")
                    item_types+=("dir")
                    item_paths+=("$relative_path")

                    # If expanded, recursively add contents (but skip apps subdirs as they're handled above)
                    if is_expanded "$relative_path" && [[ "$relative_path" != "apps" ]]; then
                        build_menu "$item" "$prefix  "
                    fi
                fi
            elif [[ -f "$item" && "$basename" == *.sh ]]; then
                # Regular script files (outside of apps)
                menu_items+=("${prefix}🚀 $basename")
                item_types+=("script")
                item_paths+=("$relative_path")
            fi
        done
    fi
}

# Refresh menu
refresh_menu() {
    menu_items=()
    item_types=()
    item_paths=()
    build_menu "$REPO_DIR" ""
}

# Display menu
display_menu() {
    clear
    echo -e "${BOLD}${CYAN}Proxmox Scripts Menu${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Use ↑↓ arrows to navigate, Enter to select/expand, 'q' to quit${NC}"
    echo ""

    for i in "${!menu_items[@]}"; do
        if [[ $i -eq $current_selection ]]; then
            echo -e "${GREEN}► ${menu_items[i]}${NC}"
        else
            echo -e "  ${menu_items[i]}"
        fi
    done

    echo ""
    echo -e "${YELLOW}Current selection: ${item_paths[current_selection]:-"N/A"}${NC}"
}

# Execute selected script or app
execute_script() {
    local item_type="${item_types[current_selection]}"
    local item_path="${item_paths[current_selection]}"

    if [[ "$item_type" == "app" ]]; then
        # Execute app main.sh
        local app_dir="$REPO_DIR/$item_path"
        local script_path="$app_dir/main.sh"

        # Export APP_DIR for the app to use
        export APP_DIR="$app_dir"

        echo -e "\n${GREEN}Executing app: $item_path${NC}"
        echo -e "${BLUE}App directory: $APP_DIR${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        if [[ -f "$script_path" ]]; then
            # Make script executable if it isn't already
            chmod +x "$script_path"

            # Execute the app's main.sh
            bash "$script_path"
        else
            echo -e "${RED}Error: main.sh not found in $app_dir${NC}"
        fi
    else
        # Execute regular script
        local script_path="$REPO_DIR/$item_path"

        echo -e "\n${GREEN}Executing: $script_path${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        if [[ -f "$script_path" ]]; then
            # Make script executable if it isn't already
            chmod +x "$script_path"

            # Execute the script
            bash "$script_path"
        else
            echo -e "${RED}Error: Script not found: $script_path${NC}"
        fi
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Execution completed. Press any key to return to menu...${NC}"
    read -n 1 -s
}

# Handle user input
handle_input() {
    local key
    IFS= read -rsn1 key

    case $key in
        $'\x1b')  # Escape sequence
            IFS= read -rsn2 key
            case $key in
                '[A')  # Up arrow
                    ((current_selection > 0)) && ((current_selection--))
                    ;;
                '[B')  # Down arrow
                    ((current_selection < ${#menu_items[@]} - 1)) && ((current_selection++))
                    ;;
            esac
            ;;
        '')  # Enter key
            if [[ "${item_types[current_selection]}" == "dir" ]]; then
                # Toggle directory expansion
                toggle_expansion "${item_paths[current_selection]}"
                refresh_menu
                # Try to keep selection on the same directory
                for i in "${!item_paths[@]}"; do
                    if [[ "${item_paths[i]}" == "${item_paths[current_selection]}" ]]; then
                        current_selection=$i
                        break
                    fi
                done
            elif [[ "${item_types[current_selection]}" == "script" || "${item_types[current_selection]}" == "app" ]]; then
                # Execute script or app
                execute_script
            fi
            ;;
        ' ')  # Space bar (alternative to expand directories)
            if [[ "${item_types[current_selection]}" == "dir" ]]; then
                toggle_expansion "${item_paths[current_selection]}"
                refresh_menu
            fi
            ;;
        'q'|'Q')  # Quit
            return 1
            ;;
    esac
    return 0
}

# Cleanup function
cleanup() {
    echo -e "${SHOW_CURSOR}"
    clear
    echo -e "${GREEN}Thank you for using Proxmox Scripts Menu!${NC}"
    exit 0
}

# Main function
main() {
    # Check if repository directory exists
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "${RED}Error: Repository directory '$REPO_DIR' not found!${NC}"
        echo -e "${YELLOW}Please make sure you're running this script from the correct directory.${NC}"
        exit 1
    fi

    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Hide cursor
    echo -e "${HIDE_CURSOR}"

    # Initial menu build
    refresh_menu

    # Main loop
    while true; do
        display_menu
        if ! handle_input; then
            break
        fi
    done

    cleanup
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
