# Group Git Clone & Update Script

Simple script to clone multiple git repositories at once. Once cloned, updating is as simple as running the script with no arguments. Works with bare or local clones. Has capability to add to rosinstall/repos/txt file on the fly and rerun. Will clone the added extras, and update the already cloned repos without reclone needed.  
Default clone is bare.

## Quick Usage

```bash
# Clone repos from a .repos file
./group-git-clone.sh myrepos.repos

# Or from a .rosinstall file
./group-git-clone.sh myworkspace.rosinstall

# Clone from a text file (needs remote address or preset for first run!)
./group-git-clone.sh -r <git remote> repos.txt

# Specify a workspace where repos are instead of (default) current directory
./group-git-clone.sh -w /path/to/workspace myrepos.repos

# Update everything with no arguments needed(if in curr dir). Need -l arg for local non-bare repos.
./group-git-clone.sh

# Specify you want to clone locally and not bare. (Will respect and clone the specified branch in .repos and .rosinstall files)
./group-git-clone.sh -l myrepos.repos

# ! Use --help to see all options
```

## Features
- Supports both bare and local repository cloning
- Multiple input formats:
  - .repos files (YAML)
  - .rosinstall files (YAML)
  - Plain text (one repo per line)
- Built-in predefined remotes
- Auto-updates existing repositories
- Dry run with -d to preview any operation without actually executing

## Options
- `-l, --local`: Clone repositories locally (non-bare)
- `-r, --remote`: Specify remote source
- `-w, --workspace`: Set target directory
- `-d, --dry-run`: Preview operations
- `-h, --help`: Show help message and predefined remotes

Notes:
- Requires `yq` for YAML files. (snap install yq) - for ubuntu
- Reports any failed operations in red error text
- Reports success in green text if everything works correct.
- Many remote presets exist in the script. Use the help menu