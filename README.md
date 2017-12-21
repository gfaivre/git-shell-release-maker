# The releaser
Simple shell script to handle git cloning/mirroring and release build
This script should be a part of a bigger deployment process, however you are free to do whatever you want with it ;)

# Usage

The syntax of releaser is the following:

releaser.sh [args] repository URL

* args are optional options for the Releaser. The available ones are :
	* --version : Prints the version number on stdout, then exits immediately
	* --branch : Specify a branch to build the release on (default master)

* repository is a git repository URL

Here is an example, assuming we need to checkout a specific commit hash.

`releaser.sh --branch my_awesome_branch --revision dd05c227116b349b1516386587130697796f09a0`

By default **HEAD** of the branch will be checked out if no revision is specified.
If no branch is given, **master** branch is considered.

Script will create the following arborescence containing the projects builds:

```
apps
├── .cached-copy
│   └── project_name
└── project_name
```

The `.cached-copy` directory will store a clone or mirror of the targeted repository. The final release (for a branch and / or revision will be found inside the `project_name` directory.)

# Licence

Releaser is covered by the GNU General Public License (GPL) version 2 and above.

# Contact

Any enhancements and suggestions are welcome.
Feel free to submit patches and bug reports on the (project page)[].
