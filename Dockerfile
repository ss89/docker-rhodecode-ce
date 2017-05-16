FROM ubuntu:17.04
RUN echo 'mysql-server-5.6 mysql-server/root_password password root' | debconf-set-selections 
RUN echo 'mysql-server-5.6 mysql-server/root_password_again password root' | debconf-set-selections
RUN apt update && apt install -y curl vim bzip2 sudo libapr1-dev libaprutil1-dev libsvn-dev mysql-server libmysqlclient-dev postgresql postgresql-contrib libpq-dev libcurl4-openssl-dev mercurial
RUN groupadd nixbld && useradd -g nixbld nixbld && usermod -G nixbld nixbld
RUN curl https://nixos.org/nix/install | USER=root sh
#   34  . /root/.nix-profile/etc/profile.d/nix.sh
RUN . /root/.nix-profile/etc/profile.d/nix.sh && nix-channel --update && nix-channel --add https://nixos.org/channels/nixos-16.03 nixpkgs && nix-channel --update
RUN . /root/.nix-profile/etc/profile.d/nix.sh && nix-env -i nix-prefetch-hg && nix-env -i nix-prefetch-git
RUN mkdir rhodecode-develop && cd rhodecode-develop && hg clone https://code.rhodecode.com/rhodecode-enterprise-ce -u v4.7.0 && hg clone https://code.rhodecode.com/rhodecode-vcsserver -u v4.7.0
RUN . /root/.nix-profile/etc/profile.d/nix.sh && cd rhodecode-develop/rhodecode-vcsserver && nix-shell
RUN . /root/.nix-profile/etc/profile.d/nix.sh && cd rhodecode-develop/rhodecode-enterprise-ce && nix-shell
RUN mkdir -p ~/.nixpkgs && touch ~/.nixpkgs/config.nix
RUN sed -i -e 's/^sqlalchemy.db1.url/#sqlalchemy.db1.url/' /rhodecode-develop/rhodecode-enterprise-ce/configs/production.ini && sed -i -e 's/#sqlalchemy.db1.url = mysql.*/sqlalchemy.db1.url = mysql:\/\/root:root@localhost\/rhodecode/' /rhodecode-develop/rhodecode-enterprise-ce/configs/production.ini && service mysql start && mysql -proot -e 'CREATE DATABASE rhodecode;'
RUN mkdir /root/my_dev_repos
COPY config.nix /root/.nixpkgs/config.nix
RUN service mysql start && . /root/.nix-profile/etc/profile.d/nix.sh && cd rhodecode-develop/rhodecode-enterprise-ce && nix-shell --run "paster setup-rhodecode configs/production.ini --user=admin --password=secret --email=admin@example.com --repos=/root/my_dev_repos --force-yes && echo done && grunt"
RUN locale-gen en_US.UTF-8 && echo "LANG=en_US.UTF-8" > /etc/default/locale && echo "LANG=en_US.UTF-8" >> /etc/environment
COPY start.sh /start.sh
RUN chmod +x start.sh
VOLUME /rhodecode-develop/rhodecode-enterprise-ce/configs /var/lib/mysql /root/my_dev_repos
EXPOSE 5000
CMD /start.sh