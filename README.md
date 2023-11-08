# chromeos-docker
Create ChromeOS docker images

## Dependencies:
On apt-based systems:
```
apt install kpartx
```

## Usage:
Several components of this script require root access.

```
REPOSITORY=YOUR_DOCKER_HUB_REPOSITORY_NAME ./chromeos_docker.sh recovery_file_url container_name chromeos_milestone arch
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
./chromeos_docker.sh https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13816.82.0_nocturne_recovery_stable-channel_mp.bin.zip nocturne 90 x86_64
```

armv7l:
```
./chromeos_docker.sh https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13904.55.0_veyron-fievel_recovery_stable-channel_fievel-mp.bin.zip fievel 91 armv7l
```
i686:
```
./chromeos_docker.sh https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_9334.72.0_x86-alex-he_recovery_stable-channel_alex-mp-v4.bin.zip alex 58 i686
./chromeos_docker.sh https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_9334.72.0_x86-zgb-he_recovery_stable-channel_zgb-mp-v3.bin.zip zgb 58 i686
```
ChromeOS Flex:
```
./chromeos_docker https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_15054.115.0_reven_recovery_stable-channel_mp-v2.bin.zip reven 106 x86_64
```
