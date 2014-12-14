###Description

A call to `helm-make` will give you a `helm` selection of this directory
Makefile's targets. Selecting a target will call `compile` on it.
You can cancel as usual with `C-g`.

###Install

Just get it from [MELPA](http://melpa.org/).

The functions that this package provides are auto-loaded, so no
additional setup is required. Unless you want to bind the functions to
a key.

###Additional stuff

#### `helm-make-do-save`

If this is set to `t`, the currently visited files from Makefile's
directory will be saved.


#### `helm-make-projectile`

This is a `helm-make` called with `(projectile-project-root)` as base directory.
