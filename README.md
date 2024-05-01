# chromeos-docker
Create ChromeOS docker images

## Usage:

```
REPOSITORY=YOUR_DOCKER_HUB_REPOSITORY_NAME ./chromeos_docker.sh container_name chromeos_milestone
```

You should have an account setup on docker's hub.
Make sure to set that account as REPOSITORY  in your environment and also make sure that you have local login from your command line enabled.

Alternately you can setup a local registry, following [these instructions]([url](https://distribution.github.io/distribution/about/deploying/))

(If you setup your registry with an ssl cert, you may have fewer problems.)

You can set the registry URL with the REPOSITORY env variable.
```
export REPOSITORY="dockerserver:5000"
sudo apt install -y uidmap golang
```

### Examples:

x86_64:
```
./chromeos_docker.sh nocturne 110
```

i686:
```
./chromeos_docker.sh x86-alex-he 58
```

aarch64:
```
./chromeos_docker.sh scarlet 115
```

armv7l:
```
./chromeos_docker.sh veyron-fievel 91
```
