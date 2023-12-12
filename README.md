# make-tom

`make-tom-sh` is a shell script for creating a TOM Toolkit-based TOM in a virtual environment. It's useful both as a way to spin up an "out-of-the-box" TOM for evaluation and as a reference for how to create a TOM for further customization and development.

## Usage
```bash
  ./make-tom.sh my_tom
```
This will create the directory `my_tom` in the current working directory, with a virtural environment (`my_tom/evn`) and TOM Toolkit (Django) project.

The basic workflow executed by the `make-tom.sh` script is:
1. Create a Python virtual environment and activate it.
2. Install from PyPI `tomtoolkit` and its dependencies (including Django) into the virtual environment.
3. Use the `django-admin startproject` command to create a basic Django project.
4. Add the one-time utility, `tom_setup`, to the basic Django project's `settings.py` `INSTALLED_APPS` list and run its `tom_setup` management command.

This will create the TOM project in a virtual environment, doing the necessary database migrations along the way. You'll be reminded of the next steps to start your TOM running and see it in a browser:
1. cd to the newly created directory.
2. activate the virtual environment with `source ./env/bin/activate`.
3. Start the Django development server with `./manage.py runserver`.
4. Point a browser to the URL given by the `runserver` management command.

### Tips and Trouble-shooting

Here's a way to generate a uniquely named TOM, which can be useful when you want to evaluate or experiment with something with the intention of deleting the directory when you're done:
```bash
./make-tom.sh name_of_your_tom_`date +'%Y%h%d_%0k%M'`
```
