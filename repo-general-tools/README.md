# Git Group General Tools

General scripts that scan git repositories one level deep and perform operations on them.

## group-quick-git.sh
A template script for running custom git commands on multiple repositories. Customize it by uncommenting or adding your own git commands in the marked section.

```bash
# Run in current directory
./group-quick-git.sh

# Run in a specific directory
./group-quick-git.sh /path/to/repos
```

Notes:
- Template includes commented commands like `git status`, `git branch`, etc.
- Modify the script by uncommenting existing commands or adding your own
- Use when you need to run the same git commands across multiple repos

## group-status-checker.sh
Shows the status of multiple git repositories including:
- Git status
- Current branch
- Remote configuration
- Last 3 commits

```bash
# Check repos in current directory
./group-status-checker.sh

# Check repos in a specific directory
./group-status-checker.sh /path/to/repos
```

Notes:
- Gives you a quick overview of each repository's state
- Useful for checking which repos have uncommitted changes or need updates

For both scripts:
- Works with repos in current directory by default
- Can specify a different directory as an argument
- Use `-h` or `--help` to see usage info
- Scans one level deep for git repositories

The main difference is that group-quick-git.sh is meant to be customized with your own commands, while group-status-checker.sh has a fixed set of status checks.