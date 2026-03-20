# make-tom

`make-tom-sh` is a shell script for creating a TOM Toolkit-based TOM in a virtual environment. It's useful both as a way to spin up an "out-of-the-box" TOM for evaluation and as a reference for how to create a TOM for further customization and development.

## Usage
The `make-tom.sh` script is all you need. Download it, make it executable (`chmod +x make-tom.sh`), and run it:
```bash
  ./make-tom.sh my_tom
```
This will create the directory `my_tom` in your current working directory with a virtual environment (`my_tom/.venv`) and TOM Toolkit (Django) project.

NOTE: Do not `source` `make-tom.sh`. First of all, it won't let you. Secondly, it contains `exit` commmands that will exit the shell you sourced it from which is not what you want. 

The basic workflow executed by the `make-tom.sh` script is:
1. Create a Python virtual environment (`.venv`) and activate it.
2. From PyPI, install `tomtoolkit` and its dependencies (including Django) into the virtual environment.
3. Use the `django-admin startproject` command to create a basic Django project.
4. Add the one-time utility, `tom_setup`, to the basic Django project's `settings.py` `INSTALLED_APPS` list and run its `tom_setup` management command.

When the `make-tom.sh` script is finished, you'll see (for example) the following output:

```bash
Here is the directory we created:
/path/to/your/cwd/my_tom
.
├── custom_code
│   ├── admin.py
│   ├── apps.py
│   ├── __init__.py
│   ├── management
│   ├── migrations
│   ├── models.py
│   ├── tests.py
│   └── views.py
├── data
├── db.sqlite3
├── manage.py
├── requirements.txt
├── static
│   └── tom_common
├── templates
├── tmp
├── my_tom
│   ├── asgi.py
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── venv -> .venv

10 directories, 14 files


Next steps:
  1. cd to the new directory. 
  2. activate the virtual environment with 'source ./.venv/bin/activate'. 
  3. Start the Django development server with './manage.py runserver'. 
  4. Point a browser to the URL given by the 'runserver' management command.
```

### Tips and Trouble-shooting

#### 1. I don't use `venv` and `pip` to manage virtual environments and dependencies in my Python projects. I use `poetry` or `uv`.

First and foremost, _ALWAYS use a virtual environment for your Python projects. DO NOT install dependencies into your system Python installation._

This script uses `pip` to install dependencies. It uses `venv` to create the virtual environment that `pip` installs those dependencies into. In practice, you'll probably use more modern tooling: If `poetry` or `uv` is your dependency manager of choice, a likely next step in your development journey is to set that up. However, that is outside the scope of this script. Our demonstration TOM ([tom-demo](https://tom-demo.lco.global/)) uses `poetry` and the tom-demo `pyproject.toml` file can be seen [here](https://github.com/LCOGT/tom-demo/blob/dev/pyproject.toml).

#### 2. Generate a TOM whose name is unique on your file system

Here's a way to generate a uniquely named TOM, which can be useful when you repeatedly want to evaluate or experiment with something with the intention of deleting the directory when you're done:
```bash
./make-tom.sh name_of_your_tom_`date +'%Y%h%d_%0k%M'`
```
This will create a uniquely named TOM Toolkit directory called, for example, `name_of_your_tom_2023Dec13_1751`.

#### 3. Install a local branch of TOMToolkit into your TOM

This is something you would do to work on a TOMToolkit issue, or develop a new feature that you might submit to us as a pull request (PR). Fantastic! Here's how:

After you've run the `make-tom.sh` script, in your TOM directory: run `pip install -e /path/to/your/local/branch/of/tom_base`

This will replace the PyPI-installed version of TOMToolkit in your virtual environment with your development branch. You can confirm this by looking at your TOM's index page and verifying that the TOMToolkit version is 0.0.0 and not the version installed from PyPI.
