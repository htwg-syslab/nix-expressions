# Syslab Nix Expressions
This project contains nix expressions for the syslab courses at HTWG Konstanz.
The expression are written in the [nix language for the package manager with the same name](https://nixos.org/nix).

This README aims to be a mixture of
* nix tutorial
* presentation for the design decisions
* labshell installation usage documentation

## Overview
<!-- TOC -->

- [Syslab Nix Expressions](#syslab-nix-expressions)
    - [Overview](#overview)
    - [Requirements](#requirements)
    - [Repository Overview](#repository-overview)
    - [Design](#design)
        - [The _labshell_ derivation](#the-_labshell_-derivation)
        - [The script _pkgs/labshell/src/labshell.sh_](#the-script-_pkgslabshellsrclabshellsh_)
            - [Modes](#modes)
            - [The 'interactive' mode](#the-interactive-mode)
            - [The 'shell' mode](#the-shell-mode)
                - [Shell mode / Invocation as #! (sharp-bang) Interpreter](#shell-mode--invocation-as--sharp-bang-interpreter)
            - [The _mkShellDerivation(.nix)_  function](#the-_mkshellderivationnix_--function)
        - [Shell derivations _(shells/default.nix)_ - Labshell flavors](#shell-derivations-_shellsdefaultnix_---labshell-flavors)
    - [Installation](#installation)
        - [The *labshell* application](#the-labshell-application)
        - [The *labshell_${flavor}* wrappers](#the-labshell_flavor-wrappers)
    - [Usage of the **labshell** application](#usage-of-the-labshell-application)
        - [On the command line in with 'interactive' mode](#on-the-command-line-in-with-interactive-mode)
        - [Shell script using the `#!` interpreter](#shell-script-using-the--interpreter)
    - [Development](#development)
        - [Clone Repository](#clone-repository)
        - [Test changes to a shell derivation](#test-changes-to-a-shell-derivation)
        - [Contribution Policy](#contribution-policy)

<!-- /TOC -->

## Requirements
In order to make use of this project you need to have _nix_ and its many utilities installed locally.
After the installation you should have these tools in your _PATH_:

* nix-prefetch-url - Used to download and store files in the nix store
* nix-instantiate - instantiates expressions to derivations
* nix-build - Build derivations without installing them to the environment
* nix-env - Evaluates expressions to derivations and installs these into your current shell environment
    You can test this with
    > `nix-env -i hello` _(will work only as root on the HTWG Syslab Containers for now)_
* [nix-shell](http://nixos.org/nix/manual/#sec-nix-shell) - launches a new shell environment based on the derivations built by nix-instantiate

## Repository Overview

The following is a simplified tree layout for the files in this repository and their purpose:

> ```
> .
> ├── default.nix (the nix entry point, exposes packages and shell flavors)
> ├── README.md (this file)
> ├── ci (scripts for integration tests)
> │   ├── complete.sh
> │   ├── install.sh
> │   ├── source.sh
> │   └── test.sh
> ├── pkgs (package definitions)
> │   ├── configured
> │   │   └── (...)
> │   ├── labshell (the package provides the wrapper scripts)
> │   │   ├── default.nix
> │   │   └── src
> │   │       └── labshell.sh (the script that executes nix-shell)
> │   └── overrides
> │       └── default.nix (some nix configuration overrides)
> └── shells
>     ├── default.nix (the definitions for the shell flavors)
>     └── mkShellDerivation.nix (the function used to build shell flavors)
> ```

## Design
The main components are the nix expressions themselves, and the _labshell.sh_ script source code.
The latter has an installable nix package in this repository.

### The _labshell_ derivation
The _labshell_ derivation that is written in _pkgs/labshell/default.nix_ allows to [install](#installation) a shell script that wraps the execution of _pkgs/labshell/src/labshell.sh_.
It is used to set default values for environment variable that alter the runtime behavior of _labshell.sh_.

To understand how this project works, **it is very useful to read the [nix manual section about writing nix expressions](http://nixos.org/nix/manual/#sec-expression-syntax) along with this README.**
Especially important is to understand how `mkDerivation` works to build an installable package, and how the installation procedure can be adjusted.
If in doubt, contact the IRC channel #nixos at FreeNode and feel free to ping _steveeJ_.

The output path of the derivation contains only one binary:
```
/nix/store/<HASH>-labshell/
└── bin
    └── labshell
```

On a local installation, this file looks like this:
```bash
$ cat $(type -P labshell)
#! /nix/store/hi4j75r312lsjhpdln9p8blyixs59hbs-bash-4.4-p12/bin/bash -e
export LABSHELL_EXPRESSIONS_LOCAL="/home/steveej/src/htwg-syslab/nix-expressions"
export LABSHELL_EXPRESSIONS_REMOTE_URL="https://github.com/htwg-syslab/nix-expressions/archive/master.tar.gz"
exec "/home/steveej/src/htwg-syslab/nix-expressions/pkgs/labshell/src/labshell.sh"  "${extraFlagsArray[@]}" "$@"
```
This wrapper is generated in the installation step of the labshell nix derivation.

### The script _pkgs/labshell/src/labshell.sh_
This is where the hard work is done to figure out which of _nix-*_ tools needs to be invoked at which time.
The main job of the script is to set up the invocation parameters for the `nix-shell` with the shell flavor that can be passed to, as described in the [usage section](#usage-of-the-labshell-application).

This section gives an idea of the supported features.

#### Modes
The script knows these modes

* interactive

    This is the default mode for working in interactive shells on the command line
* shell

    In this mode, the script behaves like a shell which allows it to be placed in the SHELL environment variable.
    This variable is used by many utilities like tmux or vim, which enables them to access the tools that are defined in the shell environments.

The environment variable *LABSHELL_MODE* can be used to set the mode, unless _labshell_ is [used as a #! interpreter), then the mode will be set to _shell_ automatically.

#### The 'interactive' mode
The _interactive_ mode launches an interactive `bash` and provides the flavor's packages.
The only argument in this case is the shell flavor, but it can also be
PATH and other environment variables are altered so that no utilities from the host are accessible.
This is done by using _nix-shell_'s `--pure` argument.

The invocation of labshell for this mode is very simple:

> `labshell FLAVOR`

#### The 'shell' mode
In 'shell' mode, the invocation of the script behaves the same as invoking `bash`, just that the shell is run with the environment defined by *LABSHELL_FLAVOR*.

In this case, the invocation looks like this

> `LABSHELL_MODE=shell [ENVIRONMENT=variables ...] labshell [ARGUMENTS PASSED TO BASH ...]`


##### Shell mode / Invocation as #! (sharp-bang) Interpreter
The _labshell_ script is designed to be used as a script interpreter, which enables the users to write scripts that can be invoked in batch jobs.

The generic syntax of a shell script looks like this:

> ```bash
> #/usr/bin/env labshell
> #!LABSHELL_OPTION1=VALUE1
> #!LABSHELL_OPTION2=VALUE2
> #!  (...)
> #!/path/to/real/interpreter argument
> commands for the real interpreter
> (...)
> ```

#### The _mkShellDerivation(.nix)_  function
This nix expression represents a function that emits an installable derivation, that can also be used to instantiate a nix-shell environment.


Some of the cornerstones of this derivation:
* The list of packages declared by the _buildInputs_ attribute of packages will be available in the environment, which is called a *flavor* within the context of this project.

* The _shellHook_ string are bash commands that are run just before the shell is spawned.

    It can be used to set environment variables or perform other initialization tasks.

### Shell derivations _(shells/default.nix)_ - Labshell flavors
The flavors effectively define an environment construct that consists a list of packages (-> buildInputs) and a string (-> shellHooks)

The dependencies and strings are organized by use-case and laboratory requirements.
The file should be self explanatory but roughly the following is true:

* all flavors are built with mkShellDerivation
* base and code collections for generic tasks and text editing (does not include language specific code completion tools)
* admin tools
* every programming language has it's own package collection for tools and compilers
* every course has its own shell derivation

The flavors that are ultimately available for installation are exposed in the _default.nix_ file by inheriting these from *shells/default.nix*, which was just discussed.

```nix
(...)
  inherit ( callPackage ./shells { } )
    shell_base
    shell_admin
    (...)
    ;
(...)
;
```

## Installation
### The *labshell* application
1. Install labshell Package from the Repository on the target machine.
    ``` bash
    REV=sj-improve-labshell-script \
        nix-env -iA labshell \
        --argstr labshellExpressionsGitHubRev ${REV}
        -f https://github.com/htwg-syslab/nix-expressions/archive/${REV}.tar.gz
    ```
    _nix-env_ will download and unpack the tar archive and automatically read its _default.nix_ file, and start evaluating the expression _pkgs.labshell_, which is a derivation that installs a labshell wrapper script in the current _PATH_.
    The example uses a development branch.

    For the HTWG Syslab Container infrastructure, this [is accomplished via _ansible-playbook_](https://github.com/htwg-syslab/infra-config/blob/master/ansible-plays/syslab-containers-config.yaml)
    _(convenience link, requires permission)_
2. On the target machine you can now see that _labshell_ is installed.
    In fact, the script in _PATH_ is a wrapper to the labshell wrapper :-)
    ```bash
    $ type labshell
    labshell is /home/sjunker/.nix-profile/bin/labshell
    $ cat $(type -P labshell)
    #! /nix/store/hi4j75r312lsjhpdln9p8blyixs59hbs-bash-4.4-p12/bin/bash -e
    exec "/nix/store/28pbgmrly69j0yvjxmrgighva0nl5jd3-sj-improve-labshell-script.tar.gz/pkgs/labshell/src/labshell.sh"  "${extraFlagsArray[@]}" "$@"
    ```
    This wrapper will probably be extexnded with default environment variables.

### The *labshell_${flavor}* wrappers
The installation is analogue to the labshell wrapper script. The following example uses a local repository for bootstrapping.

```bash
steveej@steveej-laptop ✗ ~/src/htwg-syslab/nix-expressions
$ nix-env -iA shell_base -f .
replacing old ‘shell_base’
installing ‘shell_base’
these derivations will be built:
  /nix/store/7j538si1ggq90c1vzpdz9pf7ivicmwyv-shell_base.drv
building path(s) ‘/nix/store/37fa5qrpbrqy9p905kd48bd299wyk0d4-shell_base’
installing
building path(s) ‘/nix/store/m02ly71nmxxhcinkmds9ij6xlylgpx6v-user-environment’
created 1749 symlinks in user environment
```

```bash
steveej@steveej-laptop ✓ ~/src/htwg-syslab/nix-expressions
$ cat $(type -P labshell_base)
#! /nix/store/hi4j75r312lsjhpdln9p8blyixs59hbs-bash-4.4-p12/bin/bash -e
export LABSHELL_EXPRESSIONS_LOCAL="/home/steveej/src/htwg-syslab/nix-expressions"
export LABSHELL_EXPRESSIONS_REMOTE_URL="https://github.com/htwg-syslab/nix-expressions/archive/master.tar.gz"
export LABSHELL_MODE="shell"
export LABSHELL_UPDATE="0"
export LABSHELL_FLAVOR="base"
unset LABSHELL_EXPRESSIONS_REMOTE_URL
exec "/home/steveej/src/htwg-syslab/nix-expressions/pkgs/labshell/src/labshell.sh"  "${extraFlagsArray[@]}" "$@"
```


## Usage of the **labshell** application
The _labshell_ application currently supports two modes
* interactive - to launch a shell in which the user works interactively
* shell - to make use of the environment of a labshell with the functionality of a shell

### On the command line in with 'interactive' mode
The `labshell` binary will spawn a shell with a specific flavor, which it takes as first argument.

> `labshell FLAVOR` - FLAVOR defaults to _base_

### Shell script using the `#!` interpreter

Valid LABSHELL_OPTIONS are currently:
* LABSHELL_FLAVOR=flavor - has the same effect as setting the LABSHELL_FLAVOR=flavor environment variable, or arg1 in the interactive mode


It is best to prepend `/usr/bin/env` instead of using an unreliable hardcoded path.

> ```bash
> #!/usr/bin/env labshell
> #!LABSHELL_FLAVOR=code
> #!/bin/sh -xe
> echo I'm verbose and running with the ${LABSHELL_FLAVOR} flavor.
> ```

## Development
For development the repository needs to be cloned locally.

### Clone Repository
```bash
git clone git@github.com:htwg-syslab/nix-expressions.git
pushd nix-expressions
```

### Test changes to a shell derivation
The following example assumes `$PWD` is the path of the git repository.

1. Make your desired changes
    E.g., change the shell derivations and its dependencies:
    ```bash
    $EDITOR shells/default.nix
    ```
    Read the comments in the file :-)
    If you add a new shell, you also need to add the derivation name in the _default.nix_ in the repository root.

1. Try out your changes locally
    * TODO

### Contribution Policy

The master branch is protected and requires status checks.
