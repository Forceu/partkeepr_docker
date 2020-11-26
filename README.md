# Docker / Podman Image for PartKeepr

This is an up-to-date docker / podman image containing PartKeepr.

#### Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | latest |
| arm64 | arm64v8-latest |
| armhf | arm32v7-latest |
| all* | multiarch-latest |

\* experimental

## Installation

Switch to the directory for installation and create the folders `db`, `data` and `config`.

Pull the the image with `docker pull f0rc3/partkeepr:latest`. Alternatively you can build it yourself with the command `docker build -t partkeepr:latest .`

### Setup

#### Migrating data

If you already have existing data, from the old installation copy the folder `/data/` to the new folder `data` and `/app/config` to the new folder `config`. Export your old MySql table as an .sql file and save it as "database.sql" to the same folder.

#### Podman

If you are using Podman, execute the following commands:

```
podman pod create -p 127.0.0.1:7155:80 --name partkeepr-pod 
podman run --pod partkeepr-pod --name partkeepr-mariadb -v ./db:/var/lib/mysql -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_DATABASE=partkeepr -e MYSQL_USER=partkeepr -e MYSQL_PASSWORD=partkeepr -d mariadb:10.0
podman run --name partkeepr-web --pod partkeepr-pod -v ./data:/app/data/ -v ./config:/app/app/config -d f0rc3/partkeepr:latest
podman exec -it partkeepr-web bash
```
If you need to access the server from a different device, replace the `podman pod create -p 127.0.0.1:7155:80` part with `podman pod create -p 7155:80`. Please note that this is insecure, as the traffic is not encrypted!

#### Docker

If you are using Docker, execute the following commands (change the folder paths first):

```
docker run -p 127.0.0.1:3310:3306 --name partkeepr-mariadb -v /path/to/your/folder/db:/var/lib/mysql -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_DATABASE=partkeepr -e MYSQL_USER=partkeepr -e MYSQL_PASSWORD=partkeepr -d mariadb:10.0
docker run -p 127.0.0.1:7155:80 --name partkeepr-web -v /path/to/your/folder/data:/app/data/ -v /path/to/your/folder/config:/app/app/config -d f0rc3/partkeepr:latest
docker exec -it partkeepr-web bash
```
If you need to access the server from a different device, replace the `docker run -p 127.0.0.1:7155:80` part with `docker run -p 7155:80`. Please note that this is insecure, as the traffic is not encrypted!

### Container setup

You are now in the root shell of the container. Execute the following commands:

```
chown www-data:www-data -R /app/app/config
chown www-data:www-data -R /app/data
```

Go to `http://127.0.0.1:7155/setup` and follow the setup. When asked for the auth key, execute the following command in the container shell:

```
cat /app/app/authkey.php
```

You can now exit the shell. If you are migrating your old data, make sure to import your old data before you connect to the MySql server in the setup. To import execute

```
docker exec -i partkeepr-mariadb mysql -upartkeepr -ppartkeepr partkeepr < database.sql
```

In the MySql setup, enter the IP of the MySql server. If you are using podman, you need to enter `127.0.0.1` instead of `localhost`!
