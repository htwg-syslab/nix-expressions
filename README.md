# 1. Syslab Nix Expressions
This project contains nix expressions for the syslab courses at HTWG Konstanz.
The expression are written in the [nix language for the package manager with the same name](https://nixos.org/nix).

This README aims to be a mixture of
* nix tutorial
* presentation for the design decisions
* labshell installation usage documentation

## 1.1. Overview
<!-- TOC -->

- [1. Syslab Nix Expressions](#1-syslab-nix-expressions)
    - [1.1. Overview](#11-overview)
    - [1.2. Requirements](#12-requirements)
    - [1.3. Repository Overview](#13-repository-overview)
    - [1.4. Usage and Design](#14-usage-and-design)
        - [1.4.1. The _labshell_ derivation](#141-the-_labshell_-derivation)
        - [1.4.2. Update Handling](#142-update-handling)
        - [1.4.3. The script _pkgs/labshell/src/labshell.sh_](#143-the-script-_pkgslabshellsrclabshellsh_)
        - [1.4.4. Logical modes and choice of the shell flavor](#144-logical-modes-and-choice-of-the-shell-flavor)
            - [1.4.4.1. 'Interactive' Mode](#1441-interactive-mode)
                - [1.4.4.1.1. Zero arguments passed](#14411-zero-arguments-passed)
                - [1.4.4.1.2. One Argument passed](#14412-one-argument-passed)
            - [1.4.4.2. Shell mode](#1442-shell-mode)
                - [1.4.4.2.1. Passed via environment variable *LABSHELL_FLAVOR*](#14421-passed-via-environment-variable-labshell_flavor)
                - [1.4.4.2.2. Invocation as #! (sharp-bang) Interpreter](#14422-invocation-as--sharp-bang-interpreter)
            - [1.4.4.3. The _mkShellDerivation(.nix)_  function](#1443-the-_mkshellderivationnix_--function)
        - [1.4.5. Shell derivations _(shells/default.nix)_ - Labshell flavors](#145-shell-derivations-_shellsdefaultnix_---labshell-flavors)
    - [1.5. Installation](#15-installation)
        - [1.5.1. The *labshell* application](#151-the-labshell-application)
        - [1.5.2. The *labshell_${flavor}* wrappers](#152-the-labshell_flavor-wrappers)
    - [1.6. Development](#16-development)
        - [1.6.1. Clone Repository](#161-clone-repository)
        - [1.6.2. Test changes to a shell derivation](#162-test-changes-to-a-shell-derivation)
        - [1.6.3. Tests](#163-tests)
        - [1.6.4. Contribution Policy](#164-contribution-policy)

<!-- /TOC -->

## 1.2. Requirements
In order to make use of this project you need to have _nix_ and its many utilities installed locally.
After the installation you should have these tools in your _PATH_:

* nix-prefetch-url - Used to download and store files in the nix store
* nix-instantiate - instantiates expressions to derivations
* nix-build - Build derivations without installing them to the environment
* nix-env - Evaluates expressions to derivations and installs these into your current shell environment
    You can test this with
    > `nix-env -i hello` _(will work only as root on the HTWG Syslab Containers for now)_
* [nix-shell](http://nixos.org/nix/manual/#sec-nix-shell) - launches a new shell environment based on the derivations built by nix-instantiate

## 1.3. Repository Overview

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

## 1.4. Usage and Design
The main components are the nix expressions themselves, and the _labshell.sh_ script source code.
The latter has an installable nix package in this repository.

### 1.4.1. The _labshell_ derivation
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

On a local build this file looks like this, built from a local copy of the repository with `nix-build -A labshell --arg labshellExpressionsUpdateFromLocal true`
```bash
#! /nix/store/53h800j8kgpj0a349f7wxa5hgkj1vby2-bash-4.4-p12/bin/bash -e
export LABSHELL_EXPRESSIONS_LOCAL="${LABSHELL_EXPRESSION_LOCAL:-/home/steveej/src/htwg-syslab/nix-expressions}"
export LABSHELL_EXPRESSIONS_REMOTE_URL="${LABSHELL_EXPRESSIONS_REMOTE_URL:-/home/steveej/src/htwg-syslab/nix-expressions}"
exec "/home/steveej/src/htwg-syslab/nix-expressions/pkgs/labshell/src/labshell.sh"  "${extraFlagsArray[@]}" "$@"
```
This wrapper is generated in the installation step of the labshell nix derivation.

When the wrapper is run, a new shell is spawned and PATH and other environment variables are altered so that no utilities from the host are accessible.
This is done by using _nix-shell_'s `--pure` argument.


### 1.4.2. Update Handling

> Updates only take place if *LABSHELL_UPDATE* is not 0.

In the above example the URL for updates is a local directory, which is very practical for [development](#development).
On production installations this URL will download the archive from a online repository.

### 1.4.3. The script _pkgs/labshell/src/labshell.sh_
This is where the hard work is done to figure out which of _nix-*_ tools needs to be invoked at which time.
The main job of the script is to set up the invocation parameters for the `nix-shell` with the shell flavor that can be passed to, as described in the [usage section](#usage-of-the-labshell-application).

This section gives an idea of the supported features.

### 1.4.4. Logical modes and choice of the shell flavor
The _labshell_ application currently supports two logical modes: interactive and shell.
These modes are not explicitly specified but inferred from the way the labshell script is invoked.


#### 1.4.4.1. 'Interactive' Mode
This mode is to launch a shell in which the user works interactively.

##### 1.4.4.1.1. Zero arguments passed
If _labshell_ is run without any arguments it will use the _base_ flavor and start an interactive shell with it.

##### 1.4.4.1.2. One Argument passed
In case there is exactly one arguments passed, it will be interpreted as the flavor.

> `labshell FLAVOR`

#### 1.4.4.2. Shell mode
In 'shell' mode, the invocation of the script behaves the same as invoking `bash`, just that the shell is run with the environment defined by *LABSHELL_FLAVOR*.

In this mode, labshell behaves like a shell which allows it to be placed in the SHELL environment variable.
In fact, if you spawn a labshell you will see something like this:
```bash
steveej@steveej-laptop ✓ »base@2« ~/src/htwg-syslab/nix-expressions
$ echo $SHELL
/nix/store/5zc5ljyp55k0533fp4z46kx7x02pyz2s-labshell_base/bin/labshell_base
```

This variable is used by many utilities like tmux or vim, which enables them to access the tools that are defined in the shell environments.

##### 1.4.4.2.1. Passed via environment variable *LABSHELL_FLAVOR*
In this case, the invocation looks like this

> [LABSHELL_FLAVOR=flavor...] labshell [ARGUMENTS PASSED TO BASH ...]`

##### 1.4.4.2.2. Invocation as #! (sharp-bang) Interpreter
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

Valid LABSHELL_OPTIONS are currently:
* LABSHELL_FLAVOR=flavor - has the same effect as setting the LABSHELL_FLAVOR=flavor environment variable, or arg1 in the interactive mode

It is best to prepend `/usr/bin/env` instead of using an unreliable hardcoded path.
> ```bash
> #!/usr/bin/env labshell
> #!LABSHELL_FLAVOR=code
> #!/bin/sh -xe
> echo I'm verbose and running with the ${LABSHELL_FLAVOR} flavor.
> ```

#### 1.4.4.3. The _mkShellDerivation(.nix)_  function
This nix expression represents a function that emits an installable derivation, that can also be used to instantiate a nix-shell environment.

Some of the cornerstones of this derivation:
* The list of packages declared by the _buildInputs_ attribute of packages will be available in the environment, which is called a *flavor* within the context of this project.

* The _shellHook_ string are bash commands that are run just before the shell is spawned.

    It can be used to set environment variables or perform other initialization tasks.

### 1.4.5. Shell derivations _(shells/default.nix)_ - Labshell flavors
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

## 1.5. Installation
### 1.5.1. The *labshell* application
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

### 1.5.2. The *labshell_${flavor}* wrappers
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

## 1.6. Development
For development the repository needs to be cloned locally.

### 1.6.1. Clone Repository
```bash
$ git clone git@github.com:htwg-syslab/nix-expressions.git
$ pushd nix-expressions
```

### 1.6.2. Test changes to a shell derivation
The following example assumes `$PWD` is the path of the git repository.

1. Make your desired changes
    E.g., change the shell derivations and its dependencies:
    ```bash
    $EDITOR shells/default.nix
    ```
    Read the comments in the file :-)
    If you add a new shell, you also need to add the derivation name in the _default.nix_ in the repository root.

1. Try out your changes locally
    1. Use a local build of the labshell wrapper:
        ```bash
        steveej@steveej-laptop ✓ ~/src/htwg-syslab/nix-expressions
        $ nix-build -A labshell --arg labshellExpressionsUpdateFromLocal true
        /nix/store/a8893zppmlb75lmir7czfr3mkb2r0qla-labshell
        steveej@steveej-laptop ✓ ~/src/htwg-syslab/nix-expressions
        $ ./result/bin/labshell
        Spawning shell with settings:
            flavor: 'base'
            #!-Interpreter: 0
        Please wait...
        Using expressions on filesystem /home/steveej/src/htwg-syslab/nix-expressions
        Environment initialized!
        steveej@steveej-laptop ✓ »base@2« ~/src/htwg-syslab/nix-expressions
        $
        ```
    1. Use _result/bin/labshell_ to test changes to the local repository

### 1.6.3. Tests
* If `nix-env --install ...` works for you, simply run: `./ci/complete.sh`
* [ ] Document how to run it with `nix-build` result.

### 1.6.4. Contribution Policy
The master branch is protected, hence all changes must go through Pull-Requests which require status checks.