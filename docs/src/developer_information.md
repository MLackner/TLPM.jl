# Developer Information

## TLPM Programming Manual

The TLPM programming manual comes with the *Thorlabs Optical Power Monitor* software and is typically located at `C:\Program Files (x86)\IVI Foundation\VISA\WinNT\TLPM\Manual`.


## Deploying the Documentation

Since the package depends on the *Thorlabs Optical Power Monitor* being correctly installed on the system it is non-trivial to automate the build and deployment process. Therefore, you have to semi-manually build and deploy the documentation.

### Prerequisites

Install [MkDocs](https://www.mkdocs.org) using `pip`:

```
$ pip install mkdocs
...

$ pip install python-markdown-math
...
```


### Build and Deploy

From the project folder run:

```
$ julia --project=docs/ docs/make.jl
```

This will build the documentation and make a pull request to the `gh-pages` branch in the remote repository.
