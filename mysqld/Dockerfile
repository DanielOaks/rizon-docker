FROM centos:7
MAINTAINER linostar
LABEL Description "Configure MySQL server and create tables"
RUN yum update -y
RUN yum install -y sudo mariadb mariadb-server
RUN chown -R mysql /var/lib/mysql
ADD https://gitlab.com/rizon/acid/raw/master/acid/acidcore.sql ./
COPY config.sh start_db.sh ./
EXPOSE 3306
ENTRYPOINT /bin/bash ./start_db.sh
