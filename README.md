## RhodeCode Enterprise Community Edition Docker Container


This repository aims to host the Dockerfile and some additional files used to build a Docker Container for RhodeCode.

Pre-Built Containers (x86_64) can be found [here](https://hub.docker.com/r/sstruss/rhodecode-ce/tags/)
Pre-Built Containers (armhf/armv7) can be found [here](https://hub.docker.com/r/sstruss/rhodecode-armhf/)

Both architectures will not always be up-to-date, as this is a private project of someone not from the RhodeCode team.

##### Exposed Volumes to be used:
- /rhodecode-develop/rhodecode-enterprise-ce/configs
-- for configuring your RhodeCode instance to your specific needs
- /var/lib/mysql
-- for having your Database in a save place
- /root/my_dev_repos

##### Exposed Ports to be used:
- 5000
-- for accessing your RhodeCode instance