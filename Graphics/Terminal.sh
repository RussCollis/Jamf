#!/bin/bash

# Final Emoji Prompt Installer Script
# Works with both bash and zsh, no Python dependencies
# Author: Generated for Jamf environment
# Version: 2.0

set -eo pipefail

# Configuration
EMOJI_SCRIPT_PATH="$HOME/.emoji-prompt.sh"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect current shell
detect_shell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        CURRENT_SHELL="zsh"
        CONFIG_FILE="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        CURRENT_SHELL="bash"  
        CONFIG_FILE="$HOME/.bashrc"
    else
        # Fallback based on $0 or $SHELL
        case "$0" in
            *zsh*) CURRENT_SHELL="zsh"; CONFIG_FILE="$HOME/.zshrc" ;;
            *bash*) CURRENT_SHELL="bash"; CONFIG_FILE="$HOME/.bashrc" ;;
            *)
                case "${SHELL:-/bin/bash}" in
                    */zsh) CURRENT_SHELL="zsh"; CONFIG_FILE="$HOME/.zshrc" ;;
                    *) CURRENT_SHELL="bash"; CONFIG_FILE="$HOME/.bashrc" ;;
                esac
                ;;
        esac
    fi
    
    log_info "Detected shell: $CURRENT_SHELL"
    log_info "Config file: $CONFIG_FILE"
}

# Create the emoji prompt script
create_emoji_script() {
    log_info "Creating emoji prompt script..."
    
    cat > "$EMOJI_SCRIPT_PATH" << 'EOF'
#!/bin/bash

# Simple Time-Based Emoji Prompt
# No external dependencies, works with bash and zsh

get_time_emoji() {
    local hour=$(date +%H)
    local seed=$((hour + $$))
    local emoji_index=$((seed % 6))
    
    if [[ $hour -ge 6 && $hour -lt 10 ]]; then
        # Morning (6-10am)
        local morning_emojis=("🌄" "☕️" "🍳" "🍞" "🐓" "🐔")
        echo "${morning_emojis[$emoji_index]}"
    elif [[ $hour -ge 10 && $hour -lt 12 ]]; then
        # Late morning (10-12pm)  
        local day_emojis=("📚" "💻" "🌞" "🌲" "🌸" "🌻" "☕️")
        echo "${day_emojis[$emoji_index]}"
    elif [[ $hour -ge 12 && $hour -lt 14 ]]; then
        # Lunch time (12-2pm)
        local food_emojis=("🍕" "🍔" "🍜" "🍱" "🥗" "🌮" "☕️")
        echo "${food_emojis[$emoji_index]}"
    elif [[ $hour -ge 14 && $hour -lt 17 ]]; then
        # Afternoon (2-5pm)
        local afternoon_emojis=("🌳" "📊" "🔧" "⚙️" "🖥️" "📱" "☕️")
        echo "${afternoon_emojis[$emoji_index]}"
    elif [[ $hour -ge 17 && $hour -lt 19 ]]; then
        # Evening snack (5-7pm)
        local snack_emojis=("🍪" "🍫" "🍎" "🥨" "🧁" "🍊" "☕️")
        echo "${snack_emojis[$emoji_index]}"
    elif [[ $hour -ge 19 && $hour -lt 22 ]]; then
        # Evening drinks (7-10pm)
        local drink_emojis=("🍺" "🍷" "🥃" "🍹" "☕️" "🫖")
        echo "${drink_emojis[$emoji_index]}"
    else
        # Night time (10pm-6am)
        local night_emojis=("🌙" "⭐️" "🌃" "🦉" "😴" "🌌")
        echo "${night_emojis[$emoji_index]}"
    fi
}

# Shell-specific prompt functions
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # ZSH version
    update_emoji_prompt() {
        PS1="$(get_time_emoji) %F{green}%n@%m%f %F{blue}%~%f $ "
    }
    
    # Add to precmd_functions if not already there
    if [[ ! " ${precmd_functions[@]:-} " =~ " update_emoji_prompt " ]]; then
        precmd_functions+=(update_emoji_prompt)
    fi
else
    # BASH version
    update_emoji_prompt() {
        PS1="$(get_time_emoji) \[\033[1;32m\]\u@\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] $ "
    }
    
    # Set up bash prompt command
    if [[ -z "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="update_emoji_prompt"
    else
        PROMPT_COMMAND="$PROMPT_COMMAND; update_emoji_prompt"
    fi
fi
EOF

    chmod +x "$EMOJI_SCRIPT_PATH"
    log_success "Created emoji prompt script at $EMOJI_SCRIPT_PATH"
}

# Backup config file
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Backing up existing config file..."
        cp "$CONFIG_FILE" "${CONFIG_FILE}${BACKUP_SUFFIX}"
        log_success "Backed up to ${CONFIG_FILE}${BACKUP_SUFFIX}"
    else
        log_info "No existing config file found, creating new one"
        touch "$CONFIG_FILE"
    fi
}

# Check if already configured
is_already_configured() {
    [[ -f "$CONFIG_FILE" ]] && grep -q "emoji-prompt.sh" "$CONFIG_FILE"
}

# Remove existing configuration
remove_existing_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Removing existing emoji prompt configuration..."
        
        # Create temp file without emoji prompt lines
        grep -v "# Emoji Prompt" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp1" 2>/dev/null || touch "${CONFIG_FILE}.tmp1"
        grep -v "source.*emoji-prompt.sh" "${CONFIG_FILE}.tmp1" > "${CONFIG_FILE}.tmp2" 2>/dev/null || touch "${CONFIG_FILE}.tmp2"
        grep -v "emoji-prompt installer" "${CONFIG_FILE}.tmp2" > "${CONFIG_FILE}.tmp3" 2>/dev/null || touch "${CONFIG_FILE}.tmp3"
        
        # Clean up empty lines and replace
        sed '/^[[:space:]]*$/N;/^\n$/d' "${CONFIG_FILE}.tmp3" > "$CONFIG_FILE"
        rm -f "${CONFIG_FILE}".tmp*
        
        log_success "Cleaned existing configuration"
    fi
}

# Add configuration to shell config
configure_shell() {
    if is_already_configured; then
        log_warning "Emoji prompt appears already configured"
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping configuration"
            return 0
        fi
        remove_existing_config
    fi
    
    log_info "Adding emoji prompt configuration to $CURRENT_SHELL config..."
    
    cat >> "$CONFIG_FILE" << EOF

# Emoji Prompt Configuration
# Added by emoji-prompt installer $(date)
if [[ -f ~/.emoji-prompt.sh ]]; then
    source ~/.emoji-prompt.sh
fi
EOF
    
    log_success "Added configuration to $CONFIG_FILE"
}

# Test the installation
test_installation() {
    log_info "Testing installation..."
    
    if source "$EMOJI_SCRIPT_PATH" 2>/dev/null; then
        local test_emoji
        test_emoji=$(get_time_emoji)
        if [[ -n "$test_emoji" ]]; then
            log_success "Installation test passed - current emoji: $test_emoji"
            return 0
        else
            log_warning "Installation test failed - no emoji returned"
            return 1
        fi
    else
        log_error "Installation test failed - could not source script"
        return 1
    fi
}

# Display usage instructions
show_usage() {
    local current_time=$(date +%H:%M)
    local test_emoji=$(source "$EMOJI_SCRIPT_PATH" && get_time_emoji)
    
    cat << EOF

=== Emoji Prompt Installation Complete! ===

Your time-based emoji prompt has been successfully installed!

Current setup:
- Shell: $CURRENT_SHELL  
- Config: $CONFIG_FILE
- Script: $EMOJI_SCRIPT_PATH
- Current time: $current_time
- Current emoji: $test_emoji

Emoji Schedule:
- 🌄 Morning (6:00-10:00) - Coffee, breakfast, sunrise
- 📚 Day (10:00-12:00) - Work, productivity  
- 🍕 Lunch (12:00-14:00) - Food time
- 📊 Afternoon (14:00-17:00) - Work continues
- 🍪 Snack (17:00-19:00) - Evening treats
- 🍺 Evening (19:00-22:00) - Drinks, relaxation
- 🌙 Night (22:00-6:00) - Sleep, late night

To activate:
1. Open a new terminal window, or
2. Run: source $CONFIG_FILE

Features:
- Changes every hour based on time of day
- Each terminal gets a different emoji (based on process ID)
- No external dependencies (no Python required)
- Works with both bash and zsh
- Lightweight and fast

Customization:
Edit $EMOJI_SCRIPT_PATH to:
- Add more emoji to any time period
- Adjust time ranges
- Modify colors or prompt format

Removal:
To uninstall, delete $EMOJI_SCRIPT_PATH and remove the 
configuration from $CONFIG_FILE

EOF
}

# Cleanup on interruption
cleanup() {
    log_warning "Installation interrupted"
    [[ -f "$EMOJI_SCRIPT_PATH" ]] && rm -f "$EMOJI_SCRIPT_PATH"
    log_info "Cleaned up partial installation"
}

# Main installation function
main() {
    trap cleanup INT TERM
    
    echo "=== Final Emoji Prompt Installer ==="
    echo "Simple, reliable, no external dependencies"
    echo
    
    detect_shell
    backup_config
    create_emoji_script
    configure_shell
    
    if test_installation; then
        show_usage
        log_success "🎉 Emoji prompt installation completed successfully!"
        echo
        log_info "Open a new terminal or run 'source $CONFIG_FILE' to start using emoji prompts!"
    else
        log_error "Installation completed but testing failed"
        log_error "Check $CONFIG_FILE and $EMOJI_SCRIPT_PATH for issues"
        exit 1
    fi
    
    trap - INT TERM
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
