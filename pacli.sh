#!/bin/bash

# Resources used:
# - https://developer.wordpress.org/advanced-administration/security/hardening/
# - https://developer.wordpress.org/cli/commands/
# - https://github.com/wp-cli/doctor-command

print_help() {
    # TODO: Make available commands dynamic, and also print their descriptions
    echo "Usage: pacli.sh <command> [options]"
    echo "Available commands:"
    echo "  audit --path <path> [--with-database]"
}

check_wordpress_projects() {
    # TODO: Should I also add check for wp-admin, wp-includes, and wp-content directories?
    local project_path="$1"
    echo "Checking for multiple WordPress projects in the given path..."
    wp_projects=$(find "$project_path" -type f -name "wp-config.php" -exec dirname {} \;)
    if [ -z "$wp_projects" ]; then
        echo "Um... No WordPress projects found."
    else
        IFS=$'\n' read -rd '' -a wp_projects_array <<<"$wp_projects"
        if [ ${#wp_projects_array[@]} -gt 1 ]; then
            echo "Error: Multiple WordPress projects found:"
            printf '%s\n' "${wp_projects_array[@]}"
            exit 1
        else
            echo "Good job! Only one WordPress project found."
        fi
    fi
}

search_archive_files() {
    local project_path="$1"
    echo "Searching for archive files..."
    archive_files=$(find "$project_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.rar" -o -name "*.7z" -o -name "*.tar.bz2" \) -exec realpath {} \;)
    if [ -z "$archive_files" ]; then
        echo "No archive files found. Good job!"
    else
        echo "Archive files found:"
        echo "$archive_files"
    fi
}

search_sql_files() {
    local project_path="$1"
    echo "Searching for database dump files..."
    sql_files=$(find "$project_path" -type f \( -name "*.sql" \) -exec realpath {} \;)
    if [ -z "$sql_files" ]; then
        echo "No database dump files found. Good job!"
    else
        echo "Database dump files found:"
        echo "$sql_files"
    fi
}

search_unwanted_files_and_folders() {
    # TODO: Add more unwanted files and folders
    local project_path="$1"
    local unwanted_files_and_folders=(".git" ".idea" ".vscode" ".gitignore" ".gitattribute" ".lando.yml" "docker-compose.yml" "node_modules")

    echo "Searching for unwanted files and folders..."
    for item in "${unwanted_files_and_folders[@]}"; do
        found_items=$(find "$project_path" -name "$item" -exec realpath {} \;)
        if [ -n "$found_items" ]; then
            echo "Unwanted item(s) found: $item"
            echo "$found_items"
        fi
    done
}

check_permissions() {
    local project_path="$1"
    echo "Checking permissions for all files and directories..."
    incorrect_permissions=0
    while IFS= read -r -d '' file
    do
        perm=$(stat -c '%a' "$file")
        if [[ -d $file && $perm != 755 && $perm != 750 ]]; then
            echo "Incorrect permission for directory $file: $perm"
            incorrect_permissions=1
        elif [[ -f $file && $file != "$project_path/wp-config.php" && $file != "$project_path/.htaccess" && $perm != 644 && $perm != 640 ]]; then
            echo "Incorrect permission for file $file: $perm"
            incorrect_permissions=1
        elif [[ $file == "$project_path/wp-config.php" || $file == "$project_path/.htaccess" && $perm != 440 && $perm != 400 ]]; then
            echo "Incorrect permission for file $file: $perm"
            incorrect_permissions=1
        fi
    done < <(find "$project_path" -type f -o -type d -print0)

    if [ $incorrect_permissions -eq 0 ]; then
        echo "All file and directory permissions are correct. Good job!"
    fi
}

check_core_checksums() {
    local project_path="$1"
    echo "Checking for changes in core files..."
    ./wp-cli.phar core verify-checksums --path="$project_path"
}

check_suspicious_files() {
    # TODO: Add more directories to check for suspicious files, and also add malicious code patterns to check for
    #       based on script that I have used for cleaning up TONS, Atlas
    #       E.g. eval, base64_decode, curl, etc.
    #       As this code patterns can be found in any file we can show percentage based on the file location,
    #       e.g. if file is in uploads directory then it is more suspicious than in theme directory
    local project_path="$1"
    local directories=("uploads")
    echo "Checking for suspicious files in specific directories..."
    for dir in "${directories[@]}"; do
        echo "Checking directory: $dir"
        find "$project_path/wp-content/$dir" -type f \( -name "*.php" -o -name "*.sh" \)
    done
}

check_updates() {
    local project_path="$1"
    echo "Checking for updates..."
    echo "Checking WordPress core updates..."
    ./wp-cli.phar core check-update --path="$project_path"
    echo "Checking plugin updates..."
    ./wp-cli.phar plugin list --update=available --path="$project_path"
    echo "Checking theme updates..."
    ./wp-cli.phar theme list --update=available --path="$project_path"
}

check_unused_plugins_and_themes() {
    local project_path="$1"
    echo "Checking for unused plugins and themes..."
    echo "Unused plugins:"
    ./wp-cli.phar plugin list --status=inactive --field=name --path="$project_path"
    echo "Unused themes:"
    ./wp-cli.phar theme list --status=inactive --field=name --path="$project_path"
}

check_search_engine_visibility() {
    local project_path="$1"
    echo "Checking if search engine visibility is discouraged..."
    blog_public=$(./wp-cli.phar option get "blog_public" --path="$project_path")
    if [ "$blog_public" -eq 0 ]; then
        echo "Search engine visibility is discouraged."
    else
        echo "Search engine visibility is not discouraged. Good job!"
    fi
}

check_dev_urls_in_db() {
    local project_path="$1"
    echo "Checking for development URLs in the database..."
    ./wp-cli.phar db export --path="$project_path" db.sql
    dev_urls=$(grep -oP '(localhost(:[0-9]+)?/[a-z0-9_-]+|[a-z0-9_-]+(\.[a-z0-9_-]+)*(\.dev|\.test|\.local|\.lndo\.site))' db.sql | sort | uniq)
    if [ -n "$dev_urls" ]; then
        echo "Development URLs found:"
        echo "$dev_urls"
    else
        echo "No development URLs found."
    fi
    rm db.sql
}

run_doctor() {
    local project_path="$1"
    echo "Installing doctor command..."
    ./wp-cli.phar package install wp-cli/doctor-command:@stable > /dev/null 2>&1
    echo "Running doctor..."
    ./wp-cli.phar doctor check --path="$project_path" --all
}

download_wp_cli() {
    echo "Downloading wp-cli..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    echo "wp-cli downloaded successfully."
}

remove_wp_cli() {
    echo "Removing wp-cli..."
    rm wp-cli.phar
    echo "wp-cli removed successfully."
}

check_wp_cli() {
    if ! ./wp-cli.phar --info &> /dev/null
    then
        echo "wp-cli could not be found. Downloading..."
        download_wp_cli
    fi
}

audit() {
    local project_path=""
    local with_database=false

    while (( "$#" )); do
        case "$1" in
            --path)
                project_path="$2"
                shift 2
                ;;
            --with-database)
                with_database=true
                shift
                ;;
            --with-doctor)
                with_doctor=true
                shift
                ;;
            *)
                echo "Unknown argument: $1"
                print_help
                exit 1
                ;;
        esac
    done

    if [ -z "$project_path" ]; then
        echo "You must provide the project path with --path"
        exit 1
    fi

    if [[ ! -f "$project_path/wp-config.php" || ! -d "$project_path/wp-admin" || ! -d "$project_path/wp-includes" || ! -d "$project_path/wp-content" ]]; then
        echo "Error: This script must be run from the WordPress root directory."
        exit 1
    fi

    {
        check_wordpress_projects "$project_path";
        echo "-------------------------------------"
        search_archive_files "$project_path";
        echo "-------------------------------------"
        search_sql_files "$project_path";
        echo "-------------------------------------"
        search_unwanted_files_and_folders "$project_path";
        echo "-------------------------------------"
        check_permissions "$project_path";
        echo "-------------------------------------"
        check_wp_cli
        echo "-------------------------------------"
        check_core_checksums "$project_path";
        echo "-------------------------------------"
        check_suspicious_files "$project_path";
        echo "-------------------------------------"
        check_updates "$project_path";
        echo "-------------------------------------"
        check_unused_plugins_and_themes "$project_path";
        echo "-------------------------------------"
        check_search_engine_visibility "$project_path";
        echo "-------------------------------------"
        if [ "$with_database" = true ]; then
            check_dev_urls_in_db "$project_path";
            echo "-------------------------------------"
        fi
        if [ "$with_doctor" = true ]; then
            run_doctor "$project_path";
            echo "-------------------------------------"
        fi
        remove_wp_cli
    } | tee -a "$log_file"
}

if [ $# -eq 0 ]; then
    print_help
    exit 1
fi

log_file="pacli-audit-$(date +%Y%m%d-%H%M%S).log"

command="$1"
shift
case "$command" in
    audit)
        audit "$@"
        ;;
    *)
        echo "Unknown command: $command"
        print_help
        exit 1
        ;;
esac
