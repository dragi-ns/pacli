# WordPress Audit Script

This script provides a set of checks to help ensure the health and security of WordPress project. It uses
the `wp-cli` tool to interact with your WordPress installation.

## Checks Performed

1. **Check for multiple WordPress projects**: Ensures only one WordPress project is found in the given path.
2. **Search for archive files**: Searches for archive files in the project directory.
3. **Search for database dump files**: Searches for `.sql` files in the project directory.
4. **Search for unwanted files and folders**: Searches for unwanted files and folders such
   as `.git`, `.idea`, `.vscode`, etc.
5. **Check permissions**: Checks permissions for all files and directories in the project.
6. **Check core checksums**: Checks for changes in WordPress core files.
7. **Check for suspicious files**: Checks for suspicious files in specific directories.
8. **Check for updates**: Checks for updates to WordPress core, plugins, and themes.
9. **Check for unused plugins and themes**: Lists unused plugins and themes.
10. **Check search engine visibility**: Checks if search engine visibility is discouraged.
11. **Check for development URLs in the database**: Checks for development URLs in the database (optional).
12. **Run doctor**: Runs the `wp-cli` doctor command (optional).

## Usage

To use the script, you need to run the script from the root of your WordPress project. You can do this by

```shell
./pacli.sh audit --path .
```

**Note**: You need to run the script from the root of your WordPress project as it requires access to
the `wp-config.php` file. This is usually the public_html, www, or htdocs directory.

You can also include optional checks by adding the `--with-database` and `--with-doctor` options:

```shell
./pacli.sh audit --path . --with-database --with-doctor
```

These are optional because they require additional permissions and may take longer to run.

## Logging

The script generates a log file for each run, named `pacli-audit-<timestamp>.log`. This file contains the output of all
checks performed during the run.
