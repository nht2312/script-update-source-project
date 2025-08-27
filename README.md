# Script Update Source Project

## - Laravel
- **Write log**: Create a log file with timestamp and write log both to console and file.
- **Handle line ending**: Automatically convert CRLF to LF if it detects Windows line ending error.
- **Notify via Discord**: Send log of deployment success/failure via Discord webhook.
- **Select branch**: Allow selecting branch (develop/master) via parameter or interactive.
- **Check repository connection**: Ensure the ability to connect to the repository.
- **Backup .env**: Back up the .env file before updating.
- **Update code**: Reset git, clean untracked files, fetch and reset to remote branch.
- **Check dependency changes**: Compare the hash of composer.json and composer.lock to determine if reinstallation is needed.
- **Delete unnecessary files/folders**: Delete the files/folders listed in FILES_TO_REMOVE.
- **Restore .env**: Restore the .env file from backup.
- **Maintenance mode**: If there are any changes in composer, put the site into maintenance mode, install dependencies, run migration, optimize, create sitemap, and then get out of maintenance.
- **If composer does not change**: Still run migration, storage link, optimize, and sitemap.
- **Check package outdated**: Run the command to check package version.
- **Clean up logs**: Keep the latest 5 log files and delete older ones.
