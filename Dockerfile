FROM ubuntu:18.04

#install all the necessary packages
RUN apt update && apt install -y \
	curl vim bzip2 sudo libapr1-dev libaprutil1-dev libsvn-dev \ 
	postgresql postgresql-contrib libpq-dev libcurl4-openssl-dev mercurial

#add nix build user and group
RUN groupadd nixbld && useradd -g nixbld nixbld && usermod -G nixbld nixbld

#disable nix sandboxing
RUN mkdir /etc/nix && echo 'sandbox = false' > /etc/nix/nix.conf

#download and install nix
RUN curl https://nixos.org/nix/install | USER=root sh

#ensure profile is set up right
RUN ln -s /nix/var/nix/profiles/default/etc/profile.d/nix.sh /etc/profile.d/

#set build variables
ONBUILD ENV \
    ENV=/etc/profile \
    USER=root \
    PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin \
    GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
ENV \
    ENV=/etc/profile \
    USER=root \
    PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin \
    GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    NIX_PATH=/nix/var/nix/profiles/per-user/root/channels

#update nix's package database
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
	nix-channel --update && \
	nix-channel --add https://nixos.org/channels/nixos-18.03 nixpkgs && \
	nix-channel --update
	
#preload nix-prefetch-*
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
	nix-env -i nix-prefetch-hg && \
	nix-env -i nix-prefetch-git

#download rhodecode enterprise and vcsserver
RUN mkdir rhodecode-develop && \
	cd rhodecode-develop && \
	hg clone https://code.rhodecode.com/rhodecode-enterprise-ce -u v4.19.1 && \
	hg clone https://code.rhodecode.com/rhodecode-vcsserver -u v4.19.1 && \
	hg clone https://code.rhodecode.com/rhodecode-tools-ce -u v1.4.0

#fix subversion archive
RUN cd rhodecode-develop/rhodecode-vcsserver && sed -ie 's/www.apache.org/archive.apache.org/' default.nix

#install rhodecode tools
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
        cd rhodecode-develop/rhodecode-tools-ce && \
        nix-shell

#install rhodecode vcsserver
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
	cd rhodecode-develop/rhodecode-vcsserver && \
	nix-shell

#install rhodecode enterprise
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
	cd rhodecode-develop/rhodecode-enterprise-ce && \
	nix-shell

#make sure nix has its configuration
RUN mkdir -p ~/.nixpkgs && touch ~/.nixpkgs/config.nix
	
#enable connections from all hosts for rhodecode enterprise (not vcsserver)
RUN sed -i -e 's/host = .*/host = 0.0.0.0/' /rhodecode-develop/rhodecode-enterprise-ce/configs/production.ini

#create repositories directory
RUN mkdir /root/my_dev_repos

#copy nix's configuration
COPY config.nix /root/.nixpkgs/config.nix

#setup rhodecode enterprise to use postgres, use only one worker because of a race condition currently occuring, create the database and let grunt do its tasks
RUN sed -i -e 's/postgres:qweqwe/postgres:postgres/' /rhodecode-develop/rhodecode-enterprise-ce/configs/production.ini
RUN sed -i -e 's/workers = 2/workers = 1/' /rhodecode-develop/rhodecode-enterprise-ce/configs/production.ini
RUN rm /etc/timezone
ADD .rhoderc /root/.rhoderc

RUN service postgresql start && \
	sudo -u postgres -H psql -c "ALTER USER postgres PASSWORD 'postgres';" && \
	sudo -u postgres -H psql -c "CREATE DATABASE rhodecode" && \
	USER=root . /root/.nix-profile/etc/profile.d/nix.sh && \
	cd rhodecode-develop/rhodecode-enterprise-ce && \
        nix-shell --run "rc-setup-app configs/production.ini --user=admin --password=secret --email=admin@example.com --repos=/root/my_dev_repos --force-yes --api-key DOCKER_API_KEY && apt install -y grunt && grunt && apt remove -y grunt && apt autoremove -y" && \
        export RHODECODE_API_KEY=`sudo -u postgres -H psql rhodecode -c "select api_key FROM user_api_keys where user_id=2 and role='token_role_all';" -A -t` && \
        sed -ie "s/api_key = .*/api_key = $RHODECODE_API_KEY/" /root/.rhoderc

#generate the necessary locale to start the vcsserver/rhodecode enterprise
RUN USER=root . /root/.nix-profile/etc/profile.d/nix.sh && nix-env -i glibc-locales && export LOCALE_ARCHIVE=`nix-env --installed --no-name --out-path --query glibc-locales`/lib/locale/locale-archive

COPY rhodecode /bin/rhodecode
COPY start.sh /start.sh
RUN chmod +x start.sh /bin/rhodecode
VOLUME /rhodecode-develop/rhodecode-enterprise-ce/configs /var/lib/postgresql /root/my_dev_repos
EXPOSE 5000
CMD /start.sh
