#!/bin/bash
#TJ
# Set the directory containing the git repositories
print_usage() {
    echo "Usage: $0 <folder_path>"
    echo "Example: '$0 /path/to/my/folder'"
    echo "Or without args, will run in curr directory"
    echo "'$0 ./'and "
    echo "'$0 .'"
    echo "also work for curr directory"
}

# help args
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

repo_directory=$1


if [ -n "$repo_directory" ]; then
    echo "Using provided directory $1"
    cd "$repo_directory" || exit 1
else
    echo "Using current directory $(pwd)"
fi

# loop through repos
find . -maxdepth 1 -type d ! -name "." | while read -r repo; do
    if [ -d "$repo/.git" ]; then
        echo "================="
        echo -e "\e[1;34m\e[1m###### Repository: $(pwd)${repo#.} ######\e[0m"
        echo "================="
        cd "$repo" || continue

        #cleaned name is name of repo without "./"if needed
        clean_repo_name=${repo#./}
   
        echo "Status:"
        git status
        git branch
        git remote -v
        # Uncomment the lines below to enable other git commands
        # echo "Current branch:"
        # git branch
        # echo "Recent commits:"
        git log --oneline -n 3
        # Add more git commands as needed
        echo ""
        cd - >/dev/null || exit 1
    fi
done
