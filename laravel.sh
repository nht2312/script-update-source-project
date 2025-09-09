#!/bin/bash

# Create log file with timestamp
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"
LATEST_LOG="deployment.log"

# Function to write log to both console and file
log() {
    echo "$1" | tee -a "$LOG_FILE"
    echo "$1" > "$LATEST_LOG"
}

# Always go back to the directory containing the script to ensure correct execution
cd "$(dirname "$0")"

log "🚀 [$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment process..."

# Automatically convert CRLF to LF if Windows line ending error is detected
if grep -q $'\r' "$0"; then
    log "⚠️ Detected CRLF characters (Windows). Converting to LF..."
    if command -v dos2unix >/dev/null 2>&1; then
        dos2unix "$0"
    else
        sed -i 's/\r$//' "$0"
    fi
    log "✅ Conversion completed. Please run the script again!"
    exit 1
fi

# --- Send deployment log to Discord ---
resolve_webhook() {
    # Prefer environment variable
    WEBHOOK_URL="${DISCORD_WEBHOOK_NOTIFYCATION_LOG_DEPLOYMENT:-}"
    if [ -z "$WEBHOOK_URL" ]; then
        # Try reading from .env or .env.backup if available
        local env_file=""
        if [ -f ".env" ]; then
            env_file=".env"
        elif [ -f ".env.backup" ]; then
            env_file=".env.backup"
        fi

        if [ -n "$env_file" ]; then
            WEBHOOK_URL=$(grep -E '^DISCORD_WEBHOOK_NOTIFYCATION_LOG_DEPLOYMENT=' "$env_file" | tail -n1 | cut -d'=' -f2- |
                sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        fi
    fi
}

send_discord_notification() {
    local status="$1" # SUCCESS | FAILED
    resolve_webhook
    if [ -z "$WEBHOOK_URL" ]; then
        log "⚠️ No DISCORD_WEBHOOK_NOTIFYCATION_LOG_DEPLOYMENT, skipping Discord send."
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        log "⚠️ Curl not found, cannot send Discord notification."
        return 0
    fi

    local icon="✅"
    [ "$status" != "SUCCESS" ] && icon="❌"
    local host_name
    host_name=$(hostname 2>/dev/null || echo "unknown-host")
    local content="$icon Deployment $status | branch: $TARGET_BRANCH | host: $host_name | time: $(date '+%Y-%m-%d %H:%M:%S')"

    # Send content + attach log file
    curl -sS -F "payload_json={\"content\":\"$content\"}" -F "file=@$LOG_FILE" "$WEBHOOK_URL" >/dev/null 2>&1 \
        || log "⚠️ Failed to send log to Discord."
}

on_exit() {
    local exit_code="$1"
    if [ "$exit_code" -eq 0 ]; then
        send_discord_notification "SUCCESS"
    else
        send_discord_notification "FAILED"
    fi
}

# Catch exit event to always send log (success or failure)
trap 'EXIT_CODE=$?; on_exit $EXIT_CODE' EXIT

# Choose update branch (develop/master)
TARGET_BRANCH=""
TARGET_LABEL=""

# Priority: -b|--branch parameter, then BRANCH environment variable
if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
    if [ -n "$2" ]; then
        TARGET_BRANCH="$2"
    fi
fi

if [ -z "$TARGET_BRANCH" ] && [ -n "$BRANCH" ]; then
    TARGET_BRANCH="$BRANCH"
fi

normalize_branch() {
    case "$1" in
        develop|dev)
            TARGET_BRANCH="develop"
            TARGET_LABEL="test version"
            ;;
        master|main|prod|production)
            TARGET_BRANCH="master"
            TARGET_LABEL="official version"
            ;;
        *)
            TARGET_BRANCH="$1"
            TARGET_LABEL="custom branch"
            ;;
    esac
}

if [ -n "$TARGET_BRANCH" ]; then
    normalize_branch "$TARGET_BRANCH"
fi

if [ -z "$TARGET_BRANCH" ]; then
    if [ -t 0 ]; then
        echo ""
        echo "Please choose update mode:"
        echo "  [1] Test version (develop)"
        echo "  [2] Official version (master)"
        echo "  [3] Enter another branch (custom)"
        read -p "Enter choice [1-3] (default 1): " choice
        case "${choice:-1}" in
            1)
                TARGET_BRANCH="develop"; TARGET_LABEL="test version"
                ;;
            2)
                TARGET_BRANCH="master"; TARGET_LABEL="official version"
                ;;
            3)
                read -p "Enter the name of the branch to deploy (example: feature/xyz): " custom_branch
                # Remove spaces if any
                custom_branch="${custom_branch// /}"
                if [ -z "$custom_branch" ]; then
                    TARGET_BRANCH="develop"; TARGET_LABEL="test version"
                else
                    TARGET_BRANCH="$custom_branch"; TARGET_LABEL="custom branch"
                fi
                ;;
            *)
                TARGET_BRANCH="develop"; TARGET_LABEL="test version"
                ;;
        esac
    else
        # Non-interactive: default develop
        TARGET_BRANCH="develop"
        TARGET_LABEL="test version"
    fi
fi

log "🧭 Update mode: $TARGET_BRANCH ($TARGET_LABEL)"

log "🔍 Checking connection to repository..."
if ! git ls-remote origin -h refs/heads/"$TARGET_BRANCH" &> /dev/null; then
    log "❌ Cannot connect to repository! Update process canceled."
    exit 1
else
    log " Repository connection successful! Continuing update..."
fi

# Check changes in dependency files before update
log " Checking changes in dependency files..."
DEPENDENCY_FILES=("composer.json" "composer.lock")
NEED_INSTALL_PHP=false

# Save hash of current files (before update)
declare -A CURRENT_HASHES
for file in "${DEPENDENCY_FILES[@]}"; do
    if [ -f "$file" ]; then
        CURRENT_HASHES[$file]=$(sha256sum "$file" | cut -d' ' -f1)
    else
        CURRENT_HASHES[$file]=""
    fi
done

log " Backing up .env file..."
if [ -f ".env" ]; then
    cp .env .env.backup
    log " .env file backed up successfully!"
else
    log " .env file not found, please check configuration!"
    exit 1
fi

log " Updating new code..."
log "  - Reset repo to remove local changes..."
git reset --hard 2>&1 | tee -a "$LOG_FILE"

log "  - Delete untracked files..."
git clean -fd --exclude=.env.backup 2>&1 | tee -a "$LOG_FILE"

log "  - Fetch latest code from remote..."
git fetch origin "$TARGET_BRANCH" 2>&1 | tee -a "$LOG_FILE"

log "  - Apply code from remote..."
git reset --hard origin/"$TARGET_BRANCH" 2>&1 | tee -a "$LOG_FILE"

# Check changes after code update
log " Comparing dependency files after code update..."
for file in "${DEPENDENCY_FILES[@]}"; do
    if [ -f "$file" ]; then
        NEW_HASH=$(sha256sum "$file" | cut -d' ' -f1)
        if [ "${CURRENT_HASHES[$file]}" != "$NEW_HASH" ]; then
            log " Change detected in file: $file"
            case "$file" in
                "composer.json"|"composer.lock")
                    NEED_INSTALL_PHP=true
                    ;;
            esac
        else
            log "- No change in file: $file"
        fi
    elif [ -n "${CURRENT_HASHES[$file]}" ]; then
        log " File $file has been deleted - need to update dependencies"
        case "$file" in
            "composer.json"|"composer.lock")
                NEED_INSTALL_PHP=true
                ;;
        esac
    else
        log " No previous hash for $file, skipping"
    fi
done
FILES_TO_REMOVE=(
    ".history" ".cursor" ".qodo" ".trae" ".windsurf" ".vscode"
    "Documents" "sepay" "sepay_template" "SQL_Backup"
    ".cursorignore" ".cursorrules" ".env.testing" ".windsurfrules" ".windsurfrules.bak"
    "###NOTE.md" "auto_send-request.sh" "build.sh" "git.sh"
    "log_production.log" "send_mail.ps1" "send_mail.sh"
    "treeview.sh" "treeview.txt" "Tài_nguyên_dự_án_TechNT"
    "manual_test" "version_note_dev.txt"
)

log " Deleting unnecessary files/folders:"
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -e "$file" ]; then
        log "  - Delete: $file"
        rm -rf "$file"
    fi
done

log " Restoring old .env file..."
if [ -f ".env.backup" ]; then
    cp .env.backup .env
    log " .env file restored successfully!"
else
    log " .env.backup file not found, please check configuration!"
    exit 1
fi

# Only enter maintenance mode if there are composer changes
if [ "$NEED_INSTALL_PHP" = true ]; then
    log " Putting website into maintenance mode with fixed secret (Kackac9x)..."
    php artisan down --secret="Kackac9x" | tee -a "$LOG_FILE"

    log " Installing PHP dependencies..."
    composer install --no-dev --optimize-autoloader 2>&1 | tee -a "$LOG_FILE"
    composer dump-autoload 2>&1 | tee -a "$LOG_FILE"

    log " Running migration..."
    php artisan migrate --force 2>&1 | tee -a "$LOG_FILE"

    log " Linking storage..."
    php artisan storage:link 2>&1 | tee -a "$LOG_FILE"

    log " Setting proper file permissions..."
    sudo chown -R www-data:www-data storage bootstrap/cache 2>&1 | tee -a "$LOG_FILE"
    sudo chmod -R 775 storage bootstrap/cache 2>&1 | tee -a "$LOG_FILE"

    log " Optimizing application..."
    php artisan optimize:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan cache:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan config:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan route:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan view:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan livewire:publish --assets 2>&1 | tee -a "$LOG_FILE"
    php artisan optimize 2>&1 | tee -a "$LOG_FILE"

    log " Creating sitemap..."
    if [ -f "./sitemap.sh" ]; then
        bash ./sitemap.sh 2>&1 | tee -a "$LOG_FILE"
    else
        log " sitemap.sh file not found"
    fi

    log " Bringing website out of maintenance mode..."
    php artisan up 2>&1 | tee -a "$LOG_FILE"
else
    log " No changes in composer files, skipping maintenance mode and PHP dependency installation."

    log " Running migration..."
    php artisan migrate --force 2>&1 | tee -a "$LOG_FILE"

    log " Linking storage..."
    php artisan storage:link 2>&1 | tee -a "$LOG_FILE"

    log " Setting proper file permissions..."
    sudo chown -R www-data:www-data storage bootstrap/cache 2>&1 | tee -a "$LOG_FILE"
    sudo chmod -R 775 storage bootstrap/cache 2>&1 | tee -a "$LOG_FILE"

    log " Optimizing application..."
    php artisan optimize:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan cache:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan config:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan route:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan view:clear 2>&1 | tee -a "$LOG_FILE"
    php artisan livewire:publish --assets 2>&1 | tee -a "$LOG_FILE"
    php artisan optimize 2>&1 | tee -a "$LOG_FILE"

    log " Creating sitemap..."
    if [ -f "./sitemap.sh" ]; then
        bash ./sitemap.sh 2>&1 | tee -a "$LOG_FILE"
    else
        log " sitemap.sh file not found"
    fi
fi

log " Checking outdated packages..."
php artisan dependency:versions 2>&1 | tee -a "$LOG_FILE"

log " [$(date '+%Y-%m-%d %H:%M:%S')] Update completed, website is back online! "

# Keep the latest log file
cp "$LOG_FILE" "$LATEST_LOG"

# Delete old log files (keep only the latest 5)
ls -t deployment_*.log 2>/dev/null | tail -n +6 | xargs -r rm --

log " Log saved to file: $LOG_FILE"
