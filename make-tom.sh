#!/usr/bin/env bash

set -eo pipefail

# Terminal formatting (empty strings if tput is unavailable, e.g. on dumb terminals)
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

# Ask a yes/no question. Returns 0 for yes, 1 for no.
#   $1 = prompt text
#   $2 = default ("y" or "n")
ask_yes_or_no() {
    local prompt_text="$1"
    local default_answer="$2"
    local prompt_hint
    if [ "$default_answer" = "y" ]; then
        prompt_hint="Y/n"
    else
        prompt_hint="y/N"
    fi
    printf "%s (%s): " "$prompt_text" "$prompt_hint"
    local user_answer
    read -r user_answer
    user_answer="${user_answer:-$default_answer}"
    case "$(echo "$user_answer" | tr '[:upper:]' '[:lower:]')" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# Validate that a project name is a valid Python identifier.
# Django project names become Python module names, so they must be valid
# Python identifiers: start with a letter or underscore, followed by
# letters, digits, or underscores. Python keywords are also rejected.
validate_project_name() {
    local project_name="$1"
    if [ -z "$project_name" ]; then
        echo "${bold}Error:${normal} Project name cannot be empty." >&2
        exit 1
    fi
    if ! echo "$project_name" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*$'; then
        echo "${bold}Error:${normal} \"$project_name\" is not a valid Python identifier." \
            "Use only letters, digits, and underscores. Also, cannot start with a digit)." >&2
        exit 1
    fi
    case "$project_name" in
        False|None|True|and|as|assert|async|await|break|class|continue|\
        def|del|elif|else|except|finally|for|from|global|if|import|in|\
        is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)
            echo "${bold}Error:${normal} \"$project_name\" is a Python keyword and cannot be used as a project name." >&2
            exit 1
            ;;
    esac
}

# Minimum and maximum Python versions supported by tomtoolkit.
# Update these when tomtoolkit's compatibility requirements change.
MIN_PYTHON_VERSION="3.9"
MAX_PYTHON_VERSION="3.13"

# Verify that a Python interpreter meets our requirements.
# Sets PYTHON_PATH and PYTHON_VERSION on success (return 0).
# Prints a diagnostic message and returns 1 on failure.
verify_python_interpreter() {
    local candidate_path="$1"

    # Check it exists and is executable
    if ! command -v "$candidate_path" >/dev/null 2>&1; then
        echo "\"$candidate_path\" not found or not executable."
        return 1
    fi

    # Get version string
    local version_output
    version_output=$("$candidate_path" --version 2>&1) || {
        echo "\"$candidate_path\" did not respond to --version."
        return 1
    }

    # Extract major.minor
    local major_minor_version
    major_minor_version=$(echo "$version_output" | sed -n 's/Python \([0-9]*\.[0-9]*\).*/\1/p')
    if [ -z "$major_minor_version" ]; then
        echo "Could not parse version from: $version_output"
        return 1
    fi

    # Compare against minimum and maximum supported versions
    local python_major python_minor
    python_major=$(echo "$major_minor_version" | cut -d. -f1)
    python_minor=$(echo "$major_minor_version" | cut -d. -f2)

    local required_min_major required_min_minor
    required_min_major=$(echo "$MIN_PYTHON_VERSION" | cut -d. -f1)
    required_min_minor=$(echo "$MIN_PYTHON_VERSION" | cut -d. -f2)

    local required_max_major required_max_minor
    required_max_major=$(echo "$MAX_PYTHON_VERSION" | cut -d. -f1)
    required_max_minor=$(echo "$MAX_PYTHON_VERSION" | cut -d. -f2)

    if [ "$python_major" -lt "$required_min_major" ] || { [ "$python_major" -eq "$required_min_major" ] && [ "$python_minor" -lt "$required_min_minor" ]; }; then
        echo "$version_output is below the minimum required version ($MIN_PYTHON_VERSION)."
        return 1
    fi

    if [ "$python_major" -gt "$required_max_major" ] || { [ "$python_major" -eq "$required_max_major" ] && [ "$python_minor" -gt "$required_max_minor" ]; }; then
        echo "$version_output is above the maximum supported version ($MAX_PYTHON_VERSION)."
        echo "Some tomtoolkit dependencies may not support it yet."
        return 1
    fi

    # Check that the venv module is available
    if ! "$candidate_path" -m venv --help >/dev/null 2>&1; then
        echo "$version_output at $candidate_path does not have the venv module."
        echo "On Debian/Ubuntu, install it with: sudo apt install python${python_major}.${python_minor}-venv"
        return 1
    fi

    PYTHON_PATH=$(command -v "$candidate_path")
    PYTHON_VERSION="$version_output"
    echo "Found $PYTHON_VERSION at $PYTHON_PATH"
    return 0
}

# Find a suitable Python interpreter interactively.
# Tries python3, then python on the PATH. If neither works, prompts the user.
# After finding a candidate, offers the user a chance to specify an alternative.
# Sets PYTHON_PATH and PYTHON_VERSION on success, or exits.
find_python_interpreter() {
    local candidate_path
    candidate_path=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)

    while true; do
        if [ -n "$candidate_path" ] && verify_python_interpreter "$candidate_path"; then
            # Found a valid interpreter — ask the user to confirm or override
            if ! ask_yes_or_no "Use $PYTHON_VERSION at $PYTHON_PATH?" "y"; then
                printf "Enter path to a Python interpreter: "
                read -r candidate_path
                [ -z "$candidate_path" ] && { echo "${bold}Error:${normal} No path provided." >&2; exit 1; }
                continue
            fi
            return 0
        fi

        # No valid interpreter found (or candidate was empty)
        echo "No suitable Python interpreter found."
        printf "Enter the path to a Python %s-%s interpreter (or 'exit' to quit) [exit]: " \
            "$MIN_PYTHON_VERSION" "$MAX_PYTHON_VERSION"
        read -r candidate_path
        candidate_path="${candidate_path:-exit}"
        if [ "$candidate_path" = "exit" ]; then
            echo "Exiting."
            exit 0
        fi
    done
}


# ===========================================================================
# Main workflow
# ===========================================================================

#
# 1. Gather the name of the Django project from the command line
#

if [ -z "$1" ]; then
    printf "Please provide a name for your TOM: "
    read -r TOM_DIR_NAME
    [ -z "$TOM_DIR_NAME" ] && { echo "${bold}Error:${normal} No project name provided." >&2; exit 1; }
else
    TOM_DIR_NAME="$1"
fi

# The project name must be a valid Python identifier (it becomes a Django
# module name). Validate the name as given — don't silently convert characters,
# because the directory name and Django project name must match for tom_setup
# to locate settings.py correctly.
TOM_NAME="$TOM_DIR_NAME"
validate_project_name "$TOM_NAME"

if [ -d "$TOM_DIR_NAME" ]; then
    echo "${bold}Error:${normal} Directory \"$TOM_DIR_NAME\" already exists." >&2
    exit 1
fi

#
# 2. Find a suitable Python interpreter
#

echo "${bold}Checking for your installed Python...${normal}"
find_python_interpreter

echo
echo "Using ${bold}$PYTHON_VERSION${normal} at $PYTHON_PATH"
echo "to create TOM: ${bold}$TOM_NAME${normal} in directory ${bold}$TOM_DIR_NAME${normal}"

if ! ask_yes_or_no "Do you want to continue?" "n"; then
    echo "Exiting."
    exit 0
fi

#
# 3. Create the directory that the project will live in.
#
mkdir "$TOM_DIR_NAME"
cd "$TOM_DIR_NAME"

#
# 4. Create a Python Virtual Environment in that directory (and activate it)
#
echo
echo "${bold}Creating and activating the virtual environment...${normal}"
"$PYTHON_PATH" -m venv .venv
source .venv/bin/activate
pip install --upgrade pip        # so we don't get reminded again and again

#
# 5. Create requirements file and install tomtoolkit/dependencies (including Django) to the Virtual Environment
#
echo
echo "${bold}Creating requirements.txt...${normal}"
echo tomtoolkit > requirements.txt

echo
echo "${bold}Installing tomtoolkit and dependencies into the virtual environment...${normal}"
pip install -r requirements.txt

#
# 6. Create the Django project in the directory we've created for this purpose.
#
#    NB: The second arg to startproject specifies the directory in which
#    the project is created. In this case, that's the directory that we are in, and
#    in which we have placed our virtual environment (env directory).
#
echo
echo "${bold}Creating the base Django project...${normal}"
django-admin startproject "$TOM_NAME" "../$TOM_DIR_NAME"

#
# 7. Test the sqlite3 database connection and initialize the basic Django tables
#
echo
echo "${bold}Configuring the sqlite3 database for the base Django project...${normal}"
./manage.py migrate

#
# 8. Add 'tom_setup' to the INSTALLED_APPS list of the new Django project.
#
#    The TOM Toolkit comes with a Django management command (tom_setup) which installs the
#    TOM Toolkit "apps" into your Django project. This transforms your blank Django project
#    into a TOM Toolkit-base TOM.
#
#    This happens by adding 'tom_setup' to your project's settings.py list of INSTALLED_APPS
#    and running that (now available) management command.
#
#    NB: I've seen both double- and single-quotes in the settings.py module generated by
#        django-admin startproject, so this sed command handles both.
#    NB: the GNU and BSD (macOS) versions of sed differ in they way they handle the
#        -i --in-place switch: BSD sed requires a suffix to be used. So, we avoid using
#        that and simulate -i with a copy-to-tmp-and-remove-later method.
#
echo
echo "${bold}Adding tom_setup to the settings.py INSTALLED_APPS list...${normal}"
if command -v sed > /dev/null 2>&1; then
    cp "$TOM_NAME/settings.py" "$TOM_NAME/settings.py.tmp" &&
    sed -e "s/'django.contrib.staticfiles',/'django.contrib.staticfiles',\n    'tom_setup',/" \
        -e 's/"django.contrib.staticfiles",/"django.contrib.staticfiles",\n    "tom_setup",/' <"$TOM_NAME/settings.py.tmp" >"$TOM_NAME/settings.py" &&
    rm -r "$TOM_NAME/settings.py.tmp"
else
    echo "sed not found. Please manually add 'tom_setup' to INSTALLED_APPS in $TOM_NAME/settings.py."
    if ! ask_yes_or_no "Have you added it and are ready to continue?" "n"; then
        echo "Exiting."
        exit 0
    fi
fi

echo
echo "${bold}Running the one-time tom_setup management command...${normal}"
./manage.py | grep -B 1 -A 2 tom_setup # see the newly available management command: tom_setup
./manage.py tom_setup # run the one-time tom_setup management command
echo
echo "${bold}Configuring the sqlite3 database for TOMToolkit...${normal}"
./manage.py migrate   # update the database with TOM-specific tables (Targets, Observations, etc).

#
# Wrap it up
#
echo
echo "${bold}Here is the directory we created:${normal}"
pwd
if command -v tree >/dev/null 2>&1; then
    tree -L 2 -I .venv\|__pycache__
else
    ls "$(pwd)"
fi


echo
echo "${bold}Next steps:${normal}"
echo "  1. cd to the new directory. "
echo "  2. activate the virtual environment with 'source ./.venv/bin/activate'. "
echo "  3. Start the Django development server with './manage.py runserver'. "
echo "  4. Point a browser to the URL given by the 'runserver' management command."
