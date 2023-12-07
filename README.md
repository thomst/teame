Teame
=====

Teame is a tool to clone or pull repositories from a gitea server in parallelized batch mode. Using [tea](https://gitea.com/gitea/tea) to access the gitea api.


Content
-------

- [Installation](#installation)
- [Setup](#setup)
- [Usage](#usage)
- [Examples](#examples)
- [Feedback](#feedback)


Installation
------------

### tea

*   Download binary from [here](https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64).
*   Make it executable.
*   Move it anywhere on your bin path.
*   Create a symlink.

```
wget https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64
chmod +x tea-0.9.2-linux-amd64
sudo mv tea-0.9.2-linux-amd64 /usr/local/bin/
cd /usr/local/bin/
sudo ln -s tea-0.9.2-linux-amd64 tea

```

Alternatively just follow the installation instructions [here](https://gitea.com/gitea/tea#installation).

### teame.sh

Just put teame.sh anywhere on your bin path and make it executable.

```
clone https://github.com/thomst/teame.git
sudo ln -s teame/teame.sh /usr/local/bin/teame
```

Setup
-----

*   Create a gitea access token as described [here](https://docs.gitea.com/next/development/api-usage#generating-and-listing-api-tokens).
*   Add a tea login using `tea login add`.


Usage
-----

Use `teame -h`:

```
description:
    Clone or pull gitea repositories.

usage:
    tea-me.sh -h
    tea-me.sh [-l][-d DIR][-u LOGIN][-p COUNT] PATTERN

Get or update repositories from gitea.

actions:
    -l              list repositories
    -g              clone or pull repositories
    -c              clone repositories (that does not exist in cwd)
    -p              pull repositories (that exists in cwd)
    -s              print status of repositories
    -h              print help-message

options:
    -o              use repository owner as subdirectories
    -d [DIR]        working directory (default: current working directory)
    -u [LOGIN]      tea login (default: current unix user)
    -C [COUNT]      count of parallel processes (default: 8)
```


Examples
--------

### List repositories filtered by 'my-pattern'


```
$ teame -l my-pattern
repo-with-my-pattern-in-name
another-repo-with-my-pattern-in-name
```

#### Explanation:

Teame uses `tea repos search` to get a list of repositories filtered by the search pattern.


### Clone or pull repositories

```
$ teame.sh -g my-pattern
[SUCCESS][PULLED] repo-with-my-pattern-in-name
[SUCCESS][CLONED] another-repo-with-my-pattern-in-name
```

#### Explanation

Working with the filtered list of repositories retrieved from the gitea server teame either clones or pulls the repository depending on the fact that the repository already exists in the current working directory or not.


### Show repository status

```
$ teame.sh -s my-pattern
[SUCCESS][STATUS] repo-with-my-pattern-in-name
 D deleted-file
?? new-file
[SUCCESS][CLEAN] another-repo-with-my-pattern-in-name
```

#### Explanation

Teame lists the status of each repository using a machine readable format.


Feedback
--------

Any feedback welcome: leichtfuss@systopia.de