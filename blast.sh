#!/bin/bash
# blast.sh - Management script for deployment and development of a Seablast application
# Seablast:v0.2.9
# Usage:
#   ./blast.sh                 # Runs assemble + creates required folders + checks web inaccessibility
#   ./blast.sh --base-url http://localhost # Checks if defined folders are inaccessible at http://localhost
#   ./blast.sh main            # Switches to the main branch
#   ./blast.sh phpstan-pro     # Runs PHPStan with --pro
#   ./blast.sh phpstan         # Runs PHPStan without --pro
#   ./blast.sh phpstan-remove  # Removes PHPStan package

# Color constants
NC='\033[0m' # No Color
HIGHLIGHT='\033[1;32m' # Green for sections
WARNING='\033[0;31m' # Red for warnings

# Output formatting functions
display_header() { printf "${HIGHLIGHT}%s${NC}\n" "$1"; }
display_warning() { printf "${WARNING}%s${NC}\n" "$1"; }

# Default base URL (can be overridden by --base-url)
BASE_URL="http://localhost"

# Default paths for web inaccessibility checks
DEFAULT_PATHS=("cache" "conf" "log" "src" "views")

# Function to check web inaccessibility
check_web_inaccessibility() {
    local path="$1"
    local url="${BASE_URL}${path}"
    local status_code
    status_code=$(curl -o /dev/null -s -w "%{http_code}" "$url")

    if [ "$status_code" -eq 404 ]; then
        echo "✅ $url is correctly blocked ($status_code)."
    else
        display_warning "⚠️  Warning: $url is accessible with status $status_code."
    fi
}

# Ensures required folders exist and checks web inaccessibility
setup_environment() {
    local paths=("$@") # Use provided paths or default ones
    [ ${#paths[@]} -eq 0 ] && paths=("${DEFAULT_PATHS[@]}") # If no paths given, use defaults

    for folder in "${paths[@]}"; do
        [ ! -d "$folder" ] && mkdir -p "$folder" && display_header "Created missing folder: $folder"
        check_web_inaccessibility "/$folder/"
    done

    # Create local config if not present but the dist template is available, if newly created, then stop the script so that the admin may adapt the newly created config
    [[ ! -f "conf/app.conf.local.php" && -f "conf/app.conf.dist.php" ]] && cp -p conf/app.conf.dist.php conf/app.conf.local.php && display_warning "Check/modify the newly created conf/app.conf.local.php"  && exit 0

    # conf/phinx.local.php or at least conf/phinx.dist.php is required
    if [[ ! -f "conf/phinx.local.php" ]]; then
        [[ ! -f "conf/phinx.dist.php" ]] && display_warning "phinx config is required for a Seablast app" && exit 0
        cp -p conf/phinx.dist.php conf/phinx.local.php && display_warning "Check/modify the newly created conf/phinx.local.php"
        exit 0
    fi
}

# Runs PHPUnit tests if configuration is available
run_phpunit() {
    if [[ -f "phpunit.xml" ]]; then
        display_header "-- Running PHPUnit --"
        vendor/bin/phpunit
    else
        display_warning "NO phpunit.xml CONFIGURATION"
    fi
}

# Runs Composer update and database migrations
assemble() {
    display_header "-- Updating Composer dependencies --"
    composer update -a --prefer-dist --no-progress

    display_header "-- Running database migrations --"
    vendor/bin/phinx migrate -e development --configuration ./conf/phinx.local.php
    display_header "-- Running database TESTING migrations --"
    # In order to properly unit test all features, set-up a test database, put its credentials to testing section of phinx.yml and run phinx migrate -e testing before phpunit
    # Drop tables in the testing database if changes were made to migrations
    vendor/bin/phinx migrate -e testing --configuration ./conf/phinx.local.php

    run_phpunit
}

# Switches to the main branch
back_to_main() {
    display_header "-- Switching to main branch --"
    git checkout --end-of-options main --
    git pull --progress -v --no-rebase --tags --prune -- "origin"
}

# Runs PHPStan (with or without --pro)
run_phpstan() {
    local pro_flag="$1"
    # Split the string into an array on spaces
    IFS=' ' read -r -a pro_flags <<< "$pro_flag"

    display_header "-- Installing Composer dependencies --"
    composer install -a --prefer-dist --no-progress
    display_header "-- Installing PHPStan (via Webmozart Assert plugin to allow for Assertions during static analysis) --"
    composer require --dev phpstan/phpstan-webmozart-assert --prefer-dist --no-progress --with-all-dependencies
    # TODO check if phpstan/phpstan-phpunit is needed
    display_header "-- As PHPUnit>=7 is used the PHPUnit plugin is used for better compatibility ... --"
    composer require --dev phpstan/phpstan-phpunit --prefer-dist --no-progress --with-all-dependencies

    run_phpunit

    display_header "-- Running PHPStan Analysis --"
    # $pro_flag array is expanded below
    vendor/bin/phpstan.phar --configuration=conf/phpstan.webmozart-assert.neon analyse . "${pro_flags[@]}"
}

# Removes PHPStan package
phpstan_remove() {
    display_header "-- Removing PHPStan package --"
    composer remove --dev phpstan/phpstan-phpunit
    composer remove --dev phpstan/phpstan-webmozart-assert
}

# Parse arguments
case "$1" in
    --base-url)
        shift
        BASE_URL="$1"
        shift
        ;;
esac

# Default behavior when no arguments are provided
if [ $# -eq 0 ]; then
    display_header "-- Setting up environment --"
    setup_environment "${DEFAULT_PATHS[@]}"
    display_header "-- Running assemble functionality --"
    assemble
    exit 0
fi

# Handle different command-line parameters
case "$1" in
    main) back_to_main ;;
    phpstan) run_phpstan "--memory-limit 350M" ;;
    phpstan-pro) run_phpstan "--memory-limit 350M --pro" ;;
    phpstan-remove) phpstan_remove ;;
    *)
        display_warning "❌ Unknown option: $1"
        echo "Usage: ./blast.sh [--base-url http://example.com][main|phpstan|phpstan-pro|phpstan-remove]"
        exit 1
        ;;
esac
