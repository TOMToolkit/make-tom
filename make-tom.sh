#! /bin/sh

bold=$(tput bold)
normal=$(tput sgr0)

#
# 1. Gather the name of the django project from the command line
#

if [ -z "$1" ]; then
    echo -n "Please provide a name for your TOM: "
    read TOM_DIR_NAME
else
    TOM_DIR_NAME="$1"
fi

# the TOM_NAME must be a valid Python identifier.
# So, hyphens are not allowed; change any hyphens to underscores
TOM_NAME=`echo $TOM_DIR_NAME | sed -e "s/-/_/g"`

check_python() {
    local python_path="$1"
    PYTHON_PATH=`command -v $python_path 2>/dev/null`
    if [ "$?" != 0 ]; then
        echo "Python not found on your PATH"
        echo -n "Please exit or type the pathname of a python executable: (exit/</path/to/python>)? [exit] "
        read python_answer
        python_answer="${python_answer:-exit}"
        if [ "$python_answer" = "exit" ]; then
	    echo "Exiting."
    	    exit 0;
        else
            PYTHON_PATH="$python_answer"
    	    check_python $python_answer
        fi
    else
        PYTHON_VERSION=`$PYTHON_PATH --version`
        echo "Found $PYTHON_VERSION at $PYTHON_PATH"
        echo "Do you want to use the $PYTHON_VERSION at $PYTHON_PATH? "
        echo -n "Type 'yes' or the pathname of an alternative python executable: (yes/</path/to/python>)? [yes] "
        read python_answer
        python_answer="${python_answer:-yes}"
    fi

    if [ "$python_answer" != "yes" ]; then
	echo
	echo "Checking $python_answer ..."
	check_python $python_answer
    fi
}

echo "${bold}Checking for your installed Python...${normal}"
check_python `command -v python 2>/dev/null`

#
# Tell the user what's about to happen and make sure they want to continue
#
echo
echo "Using ${bold}$PYTHON_VERSION${normal} at $PYTHON_PATH to create "
echo "create TOM: ${bold}$TOM_NAME${normal} in directory ${bold}$TOM_DIR_NAME${normal}"
# Ask the user if they want to continue with the default "No"
echo -n "Do you want to continue (y/n)? [n]: "
read user_input

# Set the default value to "N" if the input is empty
user_input="${user_input:-N}"
# Convert the user input to uppercase
user_input=$(echo "$user_input" | tr '[:lower:]' '[:upper:]')

# Check the user's choice
if [ "$user_input" = "Y" ]; then
    echo "Continuing..."
else
    echo "Exiting."
    exit 0
fi


#
# 2. Create the directory that the project will live in.
#
mkdir $TOM_DIR_NAME
cd $TOM_DIR_NAME

#
# 3. Create a Python Virtual Environment in that directory (and activate it)
#
echo
echo "${bold}Creating and activating the virtual environment...${normal}"
$PYTHON_PATH -m venv env
source env/bin/activate
pip install --upgrade pip        # so we don't get reminded again and again

#
# 4. pip install tomtoolkit and dependencies (including Django) to the Virtual Environment
#
echo
echo "${bold}Installing tomtoolkit and dependencies into the virtual environment...${normal}"
pip install tomtoolkit

#
# 5. Create the Django project in the directory we've created for this purpose.
#
#    NB: The second arg to startproject specifies the directory in which
#    the project is created. In this case, that's the directory that we are in, and
#    in which we have placed our virtual environment (env directory).
#
echo
echo "${bold}Creating the base Django project...${normal}"
django-admin startproject $TOM_NAME ../$TOM_DIR_NAME

#
# 6. Test the sqlite3 database connection and initialize the basic Django tables
#
echo
echo "${bold}Configuring the sqlite3 database for the base Django project...${normal}"
./manage.py migrate

#
# 7. Add 'tom_setup' to the INSTALLED_APPS list of the new Django project.
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
    cp $TOM_NAME/settings.py $TOM_NAME/settings.py.tmp &&
    sed -e "s/'django.contrib.staticfiles',/'django.contrib.staticfiles',\n    'tom_setup',/" \
	-e 's/"django.contrib.staticfiles",/"django.contrib.staticfiles",\n    "tom_setup",/' <$TOM_NAME/settings.py.tmp >$TOM_NAME/settings.py &&
    rm -r $TOM_NAME/settings.py.tmp
else
    echo "sed not found. Please manually edit the INSTALLED_APPS list in your settings.py file and add 'tom_setup' at the end."
    echo -n "Are you ready to continue? (Y/n)? [Y]: "
    read user_input

    # Set the default value to "N" if the input is empty
    user_input="${user_input:-Y}"
    # Convert the user input to uppercase
    user_input=$(echo "$user_input" | tr '[:lower:]' '[:upper:]')

    # Check the user's choice
    if [ "$user_input" = "Y" ]; then
        echo "Continuing..."
    else
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
    tree -L 2 -I env\|__pycache__
else
    ls `pwd`
fi


echo
echo "${bold}Next steps:${normal}"
echo "  1. cd to the new directory. "
echo "  2. activate the virtual environment with 'source ./env/bin/activate'. "
echo "  3. Start the Django development server with './manage.py runserver'. "
echo "  4. Point a browser to the URL given by the 'runserver' management command."
