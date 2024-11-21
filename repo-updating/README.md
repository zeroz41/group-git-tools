# Git Group Updating Scripts

Scripts that update multiple git repositories at the same time. They scan for git repositories one level deep from where you run them.

## pull_all_repos.sh
Updates the current branch of each repository by fetching and fast-forward merging from the specified remote.

```bash
# Updates repos in current directory using 'origin' remote
./pull_all_repos.sh origin

# Preview what would happen first
./pull_all_repos.sh -d origin

# Use a different directory 
./pull_all_repos.sh -p /path/to/repos origin
```

Notes:
- Only performs fast-forward merges to avoid conflicts
- Lists any failed repositories at the end
- Skips repos that would need manual merging

## push_all_repos.sh
Pushes the current branch of each repository to the specified remote.

```bash
# Pushes repos in current directory to 'origin' remote
./push_all_repos.sh origin

# Preview what would happen first
./push_all_repos.sh -d origin

# Use a different directory
./push_all_repos.sh -p /path/to/repos origin
```

Notes:
- Pushes the current branch of each repo to the specified remote
- Lists any failed repositories at the end
- Skips repos where the remote doesn't exist

For both scripts:
- Use `-d` or `--dry-run` to see what would happen without making changes
- Use `-h` or `--help` to see all options
- Asks for confirmation before making changes (unless using dry run)

The scripts will show you which operations failed and won't modify repositories that need manual intervention.