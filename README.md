# JupyterHub deployment

This repository contains an Ansible playbook for launching JupyterHub for the
Intro to Data Science class at the University of Illinois.

Forked from [compmodels/jupyterhub-deploy](https://github.com/compmodels/jupyterhub-deploy).

The setup is a bit complex, so this readme will try to break it down and explain everything that's going on. If you want to jump right into the details of how to deploy, see first the [installation instructions](INSTALL.md) and then the section on [deploying](#deploying).

## Overview

To understand what's going on behind the scenes, it is probably helpful to know what happens when a user accesses the server.

1. First, they go to the main url for the server.
2. This url actually points to a proxy server which authenticates the SSL connection, and proxies the connection to the JupyterHub instance running on the hub server.
3. The hub server is both a NFS server (to serve user's home directories) and the JupyterHub server.
4. Users see a JupyterHub login screen. When they click login, they are authenticated. When they access their server, JupyterHub creates a new docker container on one of the node servers running an IPython notebook server. This docker container is called "jupyter-username", where "username" is the user's username.
5. As users open IPython notebooks and run them, they are actually communicating with one of the node servers. The URL still appears the same, because the connection is first being proxied to the hub server via the proxy server, and then proxied a second time to the node server via the JupyterHub proxy.
6. Users have access to their home directory, because each node server is also a NFS client with the filesystem mounted at `/home`.

## Proxy server

The proxy server runs [nginx](http://nginx.org/en/) (pronounced "engine x"), which is a reverse HTTP proxy, in a docker container called "nginx". 
It proxies all connections from the main URL to port 8000 on the hub server.

## Hub server

The hub server fulfills two functions: it is both the NFS server, hosting all user's home directories, and it is the JupyterHub server.

### NFS

[NFS](http://en.wikipedia.org/wiki/Network_File_System) is the Network File System. 
It requires there to be a host server, where the files actually exist, and then any number of client servers that mount the NFS filesystem. 
Once the filesystem is mounted, it behaves just like a normal filesystem.

#### TODO: Implement backup.

### JupyterHub

The JupyterHub setup itself is actually pretty straightforward.

Jupyterhub is not dockerized because IllinoisNet's IP conflicts with the default Docker IP.

The differences are that our version of JupyterHub uses a special blend of GitHub authentication with local system users and spawns user servers inside docker containers on the node servers using a spawner based on the [system user docker spawner](https://github.com/jupyter/dockerspawner).
What this basically means is:

1. Users are created on the hub server with a username that needs to be the same as their GitHub username.
2. In addition to their username, JupyterHub stores the pid of each user.
3. When they login, JupyterHub authenticates the users with GitHub.
4. Once authenticated, JupyterHub spawns a docker container on one of the node servers and mounts the user's home directory inside the container.
5. A user is created inside the docker container with the appropriate username and pid, so that they have access to the files in their home directory.

### Swarm

To spawn the user docker containers, we use a load-balancing clustering system called [swarm](https://github.com/docker/swarm).
Essentially, swarm exposes an interface that looks just like the normal docker interface, and figures out in the background where to start new containers.
For example, to get a list of the docker containers that are running through swarm (i.e., the user containers that are running on all node servers):

```
docker --tls -H 127.0.0.1:2376 ps
```

To get the logs for a container running through swarm, you can run `docker --tls -H 127.0.0.1:2376 logs --tail=10 jupyter-username`, where `username` is the username for the user that you want logs from.

Swarm itself also runs in a docker container, so you can get the logs with `docker logs --tail=10 swarm`.

### TODO: Culling containers

Each docker container started through swarm is allocated 1GB of memory (currently there is no limit on CPU, but if a problem arises, we can institute one as well).
Each node server has 32GB of memory, meaning that we can run about 31*7=217 containers at once.
We actually have slightly more users than that, so we've set up a script that runs every hour and shuts down user containers if they haven't been accessed in 24 hours.
The script runs in a docker container called `cull`, so logs can be accessed via `docker logs cull`.

### TODO: Activity statistics

There is another service that runs and periodically checks which users have been active recently.
It then saves that information into a sqlite database, which can subsequently be downloaded and analyzed.
This script runs in a docker container called `stats`, so logs can be accessed via `docker logs stats`.
The sqlite database is saved to `/srv/stats/db/activity.sqlite`.

## Node servers

In general, the node servers probably don't need to be accessed directly because logs for all the user containers can be accessed through swarm on the hub server.

Each node server is a NFS client, with the NFS filesystem mounted at `/home`.
Additionally, each node server is set up to run the singleuser IPython notebook servers in docker containers.
The image is based on `edwardjkim/systemuser`, with the only differences being that `nbgrader` is installed so that students can validate and submit their assignments, and that terminado is installed so that users can have access to a terminal if they so desire.

## Deploying

:warning: Note: you'll need to install Ansible from source (`devel` branch) to
    get the current versions of the Docker modules.

To deploy this setup:

```
./script/deploy
```

Note that this will stop JupyterHub if it is currently running -- so don't run
this when people might be using the hub!

If you need to run a particular subset of the deploy operations, you can pass a `-t` flag to specify a "tag".
For example, to do all tasks relating to the statistics service, you would run `./script deploy -t stats`.
These tags are defined in the tasks themselves, for example if you look at `roles/jupyterhub_host/tasks/stats.yml` you'll see that the tasks all have a "stats" tag as well as a "rebuild-tag".

## Releasing assignments

To release an assignment:

```
./script/release
```

This will prompt you for the name of the assignment. You'll need to have also
specified the path to the assignments in `vars.local.yml` (if that file does not
exist, copy `vars.yml` and then edit it).

Also, note that if the assignment folder already exists in the user's home
directory, then it will NOT be overridden by default.

## Collecting assignments

To collect assignments:

```
./script/download
```

This will prompt you for the name of the assignment to download.
You'll need to have also specified the path to the assignments in `vars.local.yml` (if that file does not exist, copy `vars.yml` and edit it).

## Returning assignments

Coming soon!
