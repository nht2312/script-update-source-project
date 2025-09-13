# Laravel Deployment Script (updater.sh)

An automated deployment script for Laravel projects that handles code updates, dependency management, and maintenance operations with Discord notifications.

## Features

### Core Functionality
- **Write log**: Creates timestamped log files and outputs to both console and file
- **Handle line ending**: Automatically converts CRLF to LF if Windows line ending errors are detected
- **Notify via Discord**: Sends deployment success/failure logs via Discord webhook
- **Select branch**: Multiple ways to specify deployment branch (interactive, parameters, environment variables)
- **Check repository connection**: Ensures repository connectivity before deployment
- **Backup .env**: Backs up environment file before updates
- **Update code**: Performs git reset, clean untracked files, fetch and reset to remote branch
- **Check dependency changes**: Compares hash of composer.json and composer.lock to determine if reinstallation is needed
- **Delete unnecessary files/folders**: Removes development files and folders listed in FILES_TO_REMOVE
- **Restore .env**: Restores environment file from backup
- **Smart maintenance mode**: Only enters maintenance mode when composer dependencies change
- **Optimization**: Runs Laravel optimization commands (cache clear, config clear, etc.)
- **Check package outdated**: Runs dependency version checking command
- **Clean up logs**: Keeps only the latest 5 log files and deletes older ones

## Usage

### Interactive Mode
```bash
./updater.sh
```
The script will prompt you to choose between:
1. Test version (develop)
2. Official version (master)
3. Enter custom branch

### Command Line Options

#### Using --branch parameter
```bash
./updater.sh --branch master
./updater.sh -b develop
./updater.sh --branch feat/new-feature
```

#### Using direct branch specification
```bash
./updater.sh --master          # Deploy master branch
./updater.sh --develop         # Deploy develop branch
./updater.sh --feat/abc        # Deploy feature branch feat/abc
./updater.sh --hotfix/urgent   # Deploy hotfix branch
./updater.sh --release/v2.0    # Deploy release branch
```

#### Help
```bash
./updater.sh --help
./updater.sh -h
```

### Environment Variable
```bash
export BRANCH=develop
./updater.sh
```

## Configuration

### Discord Webhook (Optional)
Set the Discord webhook URL in one of these ways:

1. **Environment Variable** (Recommended):
```bash
export DISCORD_WEBHOOK_NOTIFYCATION_LOG_DEPLOYMENT="https://discord.com/api/webhooks/your-webhook-url"
```

2. **In .env file**:
```env
DISCORD_WEBHOOK_NOTIFYCATION_LOG_DEPLOYMENT="https://discord.com/api/webhooks/your-webhook-url"
```

### Prerequisites
- Git repository with remote origin
- PHP and Composer installed
- Laravel project with artisan commands
- Proper file permissions for www-data user
- curl (for Discord notifications)

## Branch Normalization

The script automatically normalizes common branch names:
- `develop`, `dev` → `develop` (test version)
- `master`, `main`, `prod`, `production` → `master` (official version)
- All other branches are treated as custom branches

## Maintenance Mode Logic

The script intelligently decides when to enter maintenance mode:

### **Enters Maintenance Mode** when:
- Changes detected in `composer.json` or `composer.lock`
- Performs: dependency installation, migration, optimization, sitemap generation

### **Skips Maintenance Mode** when:
- No changes in composer files
- Only performs: migration, storage linking, optimization, sitemap generation

## Files Automatically Removed

The script removes these development files/folders:
```
.history, .cursor, .qodo, .trae, .windsurf, .vscode
Documents, sepay, sepay_template, SQL_Backup
.cursorignore, .cursorrules, .env.testing, .windsurfrules, .windsurfrules.bak
###NOTE.md, auto_send-request.sh, build.sh, git.sh
log_production.log, send_mail.ps1, send_mail.sh
treeview.sh, treeview.txt, Tài_nguyên_dự_án_TechNT
manual_test, version_note_dev.txt
```

## Log Management

- Creates timestamped log files: `deployment_YYYYMMDD_HHMMSS.log`
- Maintains latest log as `deployment.log`
- Keeps only the 5 most recent log files
- Logs all operations to both console and file

## Error Handling

- Validates repository connection before deployment
- Backs up .env file and validates its existence
- Handles Windows line ending conversion automatically
- Sends failure notifications via Discord webhook
- Provides clear error messages and exit codes

## Examples

```bash
# Interactive deployment
./updater.sh

# Deploy specific branches
./updater.sh --master
./updater.sh --develop
./updater.sh --feat/user-authentication
./updater.sh --hotfix/security-patch

# Using traditional parameter
./updater.sh -b production
./updater.sh --branch feature/api-v2

# With environment variable
BRANCH=develop ./updater.sh

# Get help
./updater.sh --help
```

## Requirements

- Bash shell
- Git
- PHP 7.4+ / 8.x
- Composer
- Laravel project
- sudo access (for file permissions)
- curl (optional, for Discord notifications)

## Permissions

Make sure the script is executable:
```bash
chmod +x updater.sh
```

The script requires sudo access to set proper file permissions for Laravel storage and cache directories.
