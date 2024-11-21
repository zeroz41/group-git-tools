#!/bin/bash
#tj/zeroz

# bash echo colors
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[1;34m'
BOLD='\e[1m'
RESET='\e[0m'

# Predefined remotes. Add to it if you want
declare -A PREDEFINED_REMOTES=(
    ["github"]="https://github.com/zeroz41"
    #["gitlab"]="https://gitlab.com"
)

print_usage() {
    echo "Usage: $0 [OPTIONS] <input_file>"
    echo "Clone or update git repositories based on input file format"
    echo "If you run a clone on a bare repos again it will update them all from the source it created bare repos from"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -d, --dry-run           Print commands without executing them"
    echo "  -l, --local             Clone repositories locally (non-bare)"
    echo "  -r, --remote <remote>   Specify custom remote prefix"
    echo "  -w, --workspace <dir>   Specify workspace directory (default: current directory)"
    echo ""
    echo "Supported input file formats:"
    echo "  - Plain text (one repo per line)"
    echo "  - .repos file (YAML format)"
    echo "  - .rosinstall file (YAML format)"
    echo ""
    echo "Predefined remotes:"
    # loop through predefined remotes
    local max_key_length=0
    for key in "${!PREDEFINED_REMOTES[@]}"; do
        if [ ${#key} -gt $max_key_length ]; then
            max_key_length=${#key}
        fi
    done
    
    # Add remote list to help menu
    while IFS= read -r key; do
        printf "  %-${max_key_length}s : %s\n" "$key" "${PREDEFINED_REMOTES[$key]}"
    done < <(printf '%s\n' "${!PREDEFINED_REMOTES[@]}" | sort)
}

# use predefined list OR allow input
get_remote_url() {
    local remote=$1
    if [ -n "${PREDEFINED_REMOTES[$remote]}" ]; then
        echo "${PREDEFINED_REMOTES[$remote]}"
    else
        echo "$remote"
    fi
}

handle_failure() {
    local repo_name=$1
    local failure_reason=$2
    echo -e "${RED}Failed to process repository: $repo_name ($failure_reason)${RESET}"
    failed_repos+=("$repo_name: $failure_reason")
}

# dry run or no?
exec_or_print() {
    local command=$1
    local repo_name=$2
    if $dry_run; then
        echo -e "${BLUE}[DRY RUN] Would execute: $command${RESET}"
        return 0
    else
        echo -e "${BLUE}Executing: $command${RESET}"
        output=$(eval "$command" 2>&1)
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo -e "${RED}Command failed with error:${RESET}"
            echo "$output"
            return 1
        else
            echo "$output"
            return 0
        fi
    fi
}

# update bare repos. only allow ff merge from origin. don't want to merge.....
# with ability to update existing and add new repos
process_plain_file() {
    local input_file=$1
    local remote=$2
    local is_local=$3
    
    # If remote specified, get actual remote URL
    if [ -n "$remote" ]; then
        remote=$(get_remote_url "$remote")
    fi
    
    # First update all existing repos
    if ! $is_local; then
        for repo in *.git; do
            # Skip if no .git dirs found
            [[ "$repo" == "*.git" ]] && continue
            
            echo -e "${BLUE}${BOLD}Updating existing repository: $repo${RESET}"
            if ! update_bare_repo "$repo"; then
                handle_failure "${repo%.git}" "Update failed"
            fi
        done
    fi
    
    # Then process input file for any new repos
    if [ -n "$input_file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            
            # Remove .git suffix if present for consistency
            repo_name=${line%.git}
            repo_path="$repo_name.git"
            
            if $is_local; then
                if [ ! -d "$repo_name" ]; then
                    if [ -z "$remote" ]; then
                        handle_failure "$repo_name" "Remote not specified for initial clone"
                        continue
                    fi
                    exec_or_print "git clone $remote/$repo_name"
                else
                    cd "$repo_name" || continue
                    exec_or_print "git pull"
                    cd - >/dev/null || continue
                fi
            else
                # Explicitly check if this repo needs to be cloned
                if [ ! -d "$repo_path" ]; then
                    if [ -z "$remote" ]; then
                        handle_failure "$repo_name" "Remote not specified for initial clone"
                        continue
                    fi
                    echo -e "${BLUE}Cloning new repository: $repo_name${RESET}"
                    exec_or_print "git clone --bare $remote/$repo_name $repo_path"
                fi
                # No else needed here as existing repos were already updated above
            fi
        done < "$input_file"
    fi
}

# update bare repos. only allow ff merge from origin. don't want to merge.....
update_bare_repo() {
    local repo_path=$1
    if [ -d "$repo_path" ]; then
        # Store original directory
        local orig_dir=$(pwd)
        
        if ! cd "$repo_path"; then
            return 1
        fi
        
        echo -e "${BLUE}Fetching updates from remotes...${RESET}"
        
        # Fetch updates from all remotes
        if ! exec_or_print "git fetch --all --prune"; then
            cd "$orig_dir"
            return 1
        fi
        
        # Update all refs
        if ! exec_or_print "git fetch origin 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*' --prune"; then
            cd "$orig_dir"
            return 1
        fi
        
        cd "$orig_dir"
        return 0
    fi
    return 1
}

# parse and process .repos or .rosinstall files
process_yaml_file() {
    local input_file=$1
    local is_local=$2
    local file_ext="${input_file##*.}"
    
    # need yq to be installed
    if ! command -v yq &> /dev/null; then
        echo -e "${RED}Error: 'yq' is required for processing YAML files${RESET}"
        exit 1
    fi
    
    echo -e "${BLUE}Processing $file_ext file: $input_file${RESET}"
    
    if [ "$file_ext" = "repos" ]; then
        # Process .repos file
        echo -e "${BLUE}DEBUG: Processing as .repos file${RESET}"
        
        while read -r name url version; do
            [ -z "$name" ] && continue
            
            # Extract the repository name from the URL for bare clones
            remote_name=$(basename "$url" .git)
            
            echo -e "${BLUE}${BOLD}Processing repository: $name (URL: $url, Version: $version)${RESET}"
            
            if $is_local; then
                if [ ! -d "$name" ]; then
                    if [ -n "$version" ] && [ "$version" != "null" ]; then
                        if ! exec_or_print "git clone -b $version $url $name" "$name"; then
                            handle_failure "$name" "Clone failed"
                            continue
                        fi
                    else
                        if ! exec_or_print "git clone $url $name" "$name"; then
                            handle_failure "$name" "Clone failed"
                            continue
                        fi
                    fi
                else
                    if ! cd "$name"; then
                        handle_failure "$name" "Cannot access directory"
                        continue
                    fi
                    if [ -n "$version" ] && [ "$version" != "null" ]; then
                        if ! exec_or_print "git checkout $version" "$name"; then
                            handle_failure "$name" "Checkout failed"
                            cd - >/dev/null
                            continue
                        fi
                    fi
                    if ! exec_or_print "git pull" "$name"; then
                        handle_failure "$name" "Pull failed"
                    fi
                    cd - >/dev/null || true
                fi
            else
                # if bare, use the remote repository name. NOT the local name source
                if [ ! -d "$remote_name.git" ]; then
                    if ! exec_or_print "git clone --bare $url" "$remote_name"; then
                        handle_failure "$remote_name" "Bare clone failed"
                        continue
                    fi
                else
                    if ! update_bare_repo "$remote_name.git"; then
                        handle_failure "$remote_name" "Update failed"
                        continue
                    fi
                fi
            fi
        done < <(yq -r '.repositories | to_entries | .[] | [.key, .value.url, .value.version] | @tsv' "$input_file" 2>/dev/null)
    else
        # Process .rosinstall file
        echo -e "${BLUE}DEBUG: Processing as .rosinstall file${RESET}"
        
        while read -r name uri version; do
            [ -z "$name" ] && continue
            
            # get repo name
            remote_name=$(basename "$uri" .git)
            
            echo -e "${BLUE}${BOLD}Processing repository: $name (URI: $uri, Version: $version)${RESET}"
            
            if $is_local; then
                if [ ! -d "$name" ]; then
                    if [ -n "$version" ] && [ "$version" != "null" ]; then
                        if ! exec_or_print "git clone -b $version $uri $name" "$name"; then
                            handle_failure "$name" "Clone failed"
                            continue
                        fi
                    else
                        if ! exec_or_print "git clone $uri $name" "$name"; then
                            handle_failure "$name" "Clone failed"
                            continue
                        fi
                    fi
                else
                    if ! cd "$name"; then
                        handle_failure "$name" "Cannot access directory"
                        continue
                    fi
                    if [ -n "$version" ] && [ "$version" != "null" ]; then
                        if ! exec_or_print "git checkout $version" "$name"; then
                            handle_failure "$name" "Checkout failed"
                            cd - >/dev/null
                            continue
                        fi
                    fi
                    if ! exec_or_print "git pull" "$name"; then
                        handle_failure "$name" "Pull failed"
                    fi
                    cd - >/dev/null || true
                fi
            else
                # For bare clones, use the remote repository name
                if [ ! -d "$remote_name.git" ]; then
                    if ! exec_or_print "git clone --bare $uri" "$remote_name"; then
                        handle_failure "$remote_name" "Bare clone failed"
                        continue
                    fi
                else
                    if ! update_bare_repo "$remote_name.git"; then
                        handle_failure "$remote_name" "Update failed"
                        continue
                    fi
                fi
            fi
        done < <(yq -r '.[] | select(.git) | [.git."local-name", .git.uri, .git.version] | @tsv' "$input_file" 2>/dev/null)
    fi
}


dry_run=false
is_local=false
remote=""
workspace_dir="."
failed_repos=()

# args
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -d|--dry-run)
            dry_run=true
            shift
            ;;
        -l|--local)
            is_local=true
            shift
            ;;
        -r|--remote)
            remote="$2"
            shift 2
            ;;
        -w|--workspace)
            workspace_dir="$2"
            shift 2
            ;;
        *)
            input_file="$1"
            shift
            ;;
    esac
done

# Make input file path absolute before changing directories
if [ -n "$input_file" ]; then
    if [[ "$input_file" != /* ]]; then
        input_file="$(pwd)/$input_file"
    fi
fi

# Check if we're updating existing repos or need an input file
if [ -n "$workspace_dir" ] && [ -d "$workspace_dir" ]; then
    if (cd "$workspace_dir" && ls *.git >/dev/null 2>&1); then
        # Existing repos found, but keep input_file for potential new repos
        echo -e "${BLUE}Found existing repositories in workspace, will update...${RESET}"
    elif [ -z "$input_file" ]; then
        # No existing repos and no input file
        echo -e "${RED}Error: No input file specified and no existing repositories found${RESET}"
        print_usage
        exit 1
    fi
elif [ -z "$input_file" ]; then
    # No workspace dir specified and no input file
    echo -e "${RED}Error: No input file specified${RESET}"
    print_usage
    exit 1
fi
# Only validate input file if we're not just updating existing repos
if [ -n "$input_file" ]; then
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: Input file '$input_file' not found${RESET}"
        exit 1
    fi

    # validate plain text files
    file_ext="${input_file##*.}"
    if [[ "$file_ext" != "repos" && "$file_ext" != "rosinstall" ]]; then
        # Only check for remote if we don't have any existing repositories
        if [ -z "$remote" ] && ! (cd "${workspace_dir:-.}" && ls *.git >/dev/null 2>&1); then
            echo -e "${RED}Error: Remote must be specified for initial clone with plain text files${RESET}"
            print_usage
            exit 1
        fi
    fi
fi

# go to target workspace
if [ -n "$workspace_dir" ]; then
    echo -e "${BLUE}Using workspace directory: $workspace_dir${RESET}"
    mkdir -p "$workspace_dir"
    cd "$workspace_dir" || exit 1
fi

# If we have existing repos but no input file, just update them
if [ -z "$input_file" ]; then
    if $is_local; then
        for dir in */; do
            # Skip if no directories found
            [[ "$dir" == "*/" ]] && continue
            
            # Remove trailing slash
            dir=${dir%/}
            
            # Check if it's a git repo
            if [ -d "$dir/.git" ]; then
                echo -e "${BLUE}${BOLD}Processing local repository: $dir${RESET}"
                cd "$dir" || continue
                if ! exec_or_print "git pull" "$dir"; then
                    handle_failure "$dir" "Pull failed"
                fi
                cd - >/dev/null || continue
            fi
        done
    else
        for repo in *.git; do
            echo -e "${BLUE}${BOLD}Processing repository: $repo${RESET}"
            if ! update_bare_repo "$repo"; then
                handle_failure "${repo%.git}" "Update failed"
            fi
        done
    fi
else
    # repos,rosinstall or plain text?
    case $file_ext in
        repos|rosinstall)
            process_yaml_file "$input_file" "$is_local"
            ;;
        *)
            process_plain_file "$input_file" "$remote" "$is_local"
            ;;
    esac
fi

# Print summary
echo -e "\n${BLUE}${BOLD}All repositories processed.${RESET}"
if [ ${#failed_repos[@]} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All operations completed successfully.${RESET}"
else
    echo -e "${RED}${BOLD}The following operations failed:${RESET}"
    printf '%s\n' "${failed_repos[@]}" | while IFS= read -r line; do
        echo -e "${RED}- $line${RESET}"
    done
    exit 1
fi

if $dry_run; then
    echo -e "\n${BLUE}-------------------------------------------------------${RESET}"
    echo -e "${BLUE}This was a dry run. No actual changes were made.${RESET}"
    echo -e "${BLUE}-------------------------------------------------------${RESET}"
fi