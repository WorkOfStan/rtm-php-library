#!/bin/bash
# blast.sh - Management script for deployment and development of a Seablast application
# Seablast:v0.2.17.3
# Fail fast on real script errors:
# -e: stop on unexpected non-zero exit codes
# -u: treat unset variables as errors, which makes argument handling stricter
# -o pipefail: fail a pipeline when any command in it fails
set -euo pipefail

# Usage:
#   ./blast.sh                          # Runs assemble + creates required folders + checks web inaccessibility
#   ./blast.sh --base-url http://localhost  # Runs the default action with a custom base URL for folder checks
#   ./blast.sh clean                    # Previews and deletes temporary cache/audio marker files after confirmation
#   ./blast.sh main                     # Switches to the main branch (after confirmation)
#   ./blast.sh phpstan                  # Runs PHPStan without --pro
#   ./blast.sh phpstan-pro              # Runs PHPStan with --pro
#   ./blast.sh phpstan-remove           # Removes PHPStan package
#   ./blast.sh self-update              # Self-update the app version, i.e. checks and overrides itself with a newer version if available in the vendor directory

# Color constants
NC='\033[0m'           # No Color
HIGHLIGHT='\033[1;32m' # Green for sections
WARNING='\033[0;31m'   # Red for warnings

# Output formatting functions
display_header() { printf "${HIGHLIGHT}%s${NC}\n" "$1"; }
display_warning() { printf "${WARNING}%s${NC}\n" "$1"; }

# Shared usage output so CLI validation errors stay consistent.
print_usage() {
	echo "Usage: ./blast.sh [--base-url http://example.com] [clean|main|phpstan|phpstan-pro|phpstan-remove|self-update]"
	echo "(See the beginning of the code for the explanation.)"
}

# Default base URL (can be overridden by --base-url)
BASE_URL="http://localhost"

# Default paths for web inaccessibility checks
DEFAULT_PATHS=("cache" "conf" "log" "src" "views")

# Function to check web inaccessibility
check_web_inaccessibility() {
	local path="$1"
	local url="${BASE_URL}${path}"
	local status_code

	# With `set -e`, run curl inside `if` so connection problems only warn and do not
	# abort the whole setup when a local web server is temporarily unavailable.
	if status_code=$(curl -o /dev/null -s -w "%{http_code}" "$url" 2>/dev/null); then
		if [ "$status_code" -eq 404 ] || [ "$status_code" -eq 403 ]; then
			echo "[OK] $url is correctly blocked ($status_code)."
		else
			display_warning "Warning: $url is accessible with status $status_code."
		fi
	else
		display_warning "Warning: $url could not be checked because curl could not reach it."
	fi
}

# Ensures required folders exist and checks web inaccessibility
setup_environment() {
	local paths=("$@")                                      # Use provided paths or default ones
	[ ${#paths[@]} -eq 0 ] && paths=("${DEFAULT_PATHS[@]}") # If no paths given, use defaults

	local has_curl=false
	if command -v curl &>/dev/null; then
		has_curl=true
	else
		display_warning "Warning: curl is not installed, so security of folders cannot be tested."
	fi
	for folder in "${paths[@]}"; do
		[ ! -d "$folder" ] && mkdir -p "$folder" && display_header "Created missing folder: $folder"
		$has_curl && check_web_inaccessibility "/$folder/"
	done

	# Create local config if not present but the dist template is available. If newly
	# created, then stop the script so that the admin may adapt the new config first.
	[[ ! -f "conf/app.conf.local.php" && -f "conf/app.conf.dist.php" ]] && cp -p conf/app.conf.dist.php conf/app.conf.local.php && display_warning "Check/modify the newly created conf/app.conf.local.php" && exit 0

	# conf/phinx.local.php or at least conf/phinx.dist.php is required
	if [[ ! -f "conf/phinx.local.php" ]]; then
		[[ ! -f "conf/phinx.dist.php" ]] && display_warning "conf/phinx.dist.php template is required for a Seablast app" && exit 0
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
		display_warning "NO phpunit.xml CONFIGURATION, no PHPUnit testing"
	fi
}

# Runs Composer update and database migrations
assemble() {
	display_header "-- Updating Composer dependencies --"
	composer update -a --prefer-dist --no-progress

	display_header "-- Running database migrations --"
	vendor/bin/phinx migrate -e development --configuration ./conf/phinx.local.php
	display_header "-- Running database TESTING migrations --"
	# In order to properly unit test all features, set-up a test database, put its
	# credentials to the testing section of the phinx configuration file and run
	# phinx migrate -e testing before phpunit.
	# Drop tables in the testing database if changes were made to migrations.
	vendor/bin/phinx migrate -e testing --configuration ./conf/phinx.local.php

	run_phpunit
}

# Previews and removes temporary files created during development
clean_temp_files() {
	display_header "-- Files to be deleted (preview) --"
	# ls returns non-zero when no glob matches, which is acceptable for this preview.
	# We do not want the script to stop in that case, so we append "|| true".
	ls -1 cache/*.php cache/*.lock uploads/audios/*.del 2>/dev/null || true
	echo

	read -r -p "Do you really want to delete the files listed above? Type YES to continue: " confirm
	if [[ "${confirm}" != "YES" ]]; then
		echo "Aborted."
		exit 0
	fi

	display_header "-- Deleting temporary files --"
	# -v: verbose, prints the name of each removed file
	# -f: force, ignore nonexistent files and do not prompt
	# Keep "2>/dev/null || true" so unmatched globs do not abort the script under
	# `set -e` in environments with slightly different shell behaviour.
	rm -fv cache/*.php cache/*.lock 2>/dev/null || true
	rm -fv uploads/audios/*.del 2>/dev/null || true

	echo "Done."
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
	IFS=' ' read -r -a pro_flags <<<"$pro_flag"

	display_header "-- Installing Composer dependencies --"
	composer install -a --prefer-dist --no-progress
	display_header "-- Installing PHPStan (via Webmozart Assert plugin to allow for Assertions during static analysis) --"
	composer require --dev phpstan/phpstan-webmozart-assert --prefer-dist --no-progress --with-all-dependencies
	if [[ -f "phpunit.xml" ]]; then
		display_header "-- As PHPUnit>=7 is used the PHPUnit plugin is used for better compatibility ... --"
		composer require --dev phpstan/phpstan-phpunit --prefer-dist --no-progress --with-all-dependencies
	else
		display_warning "NO phpunit.xml CONFIGURATION, no PHPStan PHPUnit plugin required"
	fi

	run_phpunit

	display_header "-- Running PHPStan Analysis --"
	# $pro_flag array is expanded below
	vendor/bin/phpstan.phar --configuration=conf/phpstan.webmozart-assert.neon analyse . "${pro_flags[@]}"
}

# Removes PHPStan package
phpstan_remove() {
	display_header "-- Removing PHPStan package --"
	# It does not matter if phpstan/phpstan-phpunit was not required before.
	composer remove --dev phpstan/phpstan-phpunit
	composer remove --dev phpstan/phpstan-webmozart-assert
}

# Self-update function: checks for an updated version of this script and overrides itself if found
self_update() {
	local update_file="./vendor/seablast/seablast/blast.sh"
	if [ -f "$update_file" ]; then
		if [ "$update_file" -nt "$0" ]; then
			cp "$update_file" "$0"
			display_header "Self-update successful: Updated to the newer version from $update_file"
		else
			display_warning "Self-update: Update file found, but it is not newer than the current version."
		fi
	else
		display_warning "Self-update: Update file not found at $update_file"
	fi
}

# Parse optional base-url argument.
# Under `set -u`, use `${1-}` / `${2-}` so a missing CLI value can be handled
# with a friendly error instead of an immediate "unbound variable" exit.
if [[ "${1-}" == "--base-url" ]]; then
	if [[ -z "${2-}" ]]; then
		display_warning "Missing value for --base-url."
		print_usage
		exit 1
	fi
	BASE_URL="$2"
	shift 2
fi

# Default behavior when no arguments are provided
if [ $# -eq 0 ]; then
	display_header "-- Setting up environment --"
	setup_environment "${DEFAULT_PATHS[@]}"
	display_header "-- Running assemble functionality --"
	assemble
	exit 0
fi

# Handle command-line parameters
case "${1-}" in
clean)
	clean_temp_files
	;;
main)
	printf "Switches your working tree to the specified branch: main. Git will then fetch from origin (showing you a verbose progress report), bringing in all branches and tags, deleting any remote-tracking branches that have been removed on the server, and then merge (not rebase) the corresponding remote branch into your current branch.\n"
	read -r -n1 -p "Continue? [y/N] " reply
	echo
	[[ $reply =~ ^[Yy]$ ]] || {
		echo "Aborted."
		exit 1
	}
	back_to_main
	;;
phpstan)
	run_phpstan "--memory-limit 350M"
	;;
phpstan-pro)
	run_phpstan "--memory-limit 350M --pro"
	;;
phpstan-remove)
	phpstan_remove
	;;
self-update)
	self_update
	;;
*)
	display_warning "Unknown option: ${1-}"
	print_usage
	exit 1
	;;
esac
