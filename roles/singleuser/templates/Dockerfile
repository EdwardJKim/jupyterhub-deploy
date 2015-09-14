# Build as jupyter/jupyterhub-singleuser
# Run with the DockerSpawner in JupyterHub

FROM lcdm/rppdm-standalone

USER root
ENV HOSTNAME "{{ servicenet_ip }}"

RUN echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" > /etc/apt/sources.list.d/webupd8team-java.list &&\
    echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list.d/webupd8team-java.list &&\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886 &&\
    apt-get -y update &&\
    echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections &&\
    apt-get install -y oracle-java7-installer

ENV SPARK_VERSION 1.4.1
ENV SPARK_HOME /usr/local/src/spark-$SPARK_VERSION

RUN mkdir -p $SPARK_HOME &&\
    curl -s http://mirror.cc.columbia.edu/pub/software/apache//spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop2.6.tgz | \
        tar -xz -C $SPARK_HOME --strip-components=1

RUN pip install py4j

ENV PYTHONPATH $SPARK_HOME/python/:$PYTHONPATH
ENV PYTHONPATH $SPARK_HOME/python/lib/py4j-0.8.2.1-src.zip:$PYTHONPATH
#ENV PYSPARK_PYTHON python3
ENV PYSPARK_SUBMIT_ARGS "--master spark://10.0.3.70:7077 pyspark-shell"

# fetch juptyerhub-singleuser entrypoint
ADD https://raw.githubusercontent.com/jupyter/jupyterhub/master/jupyterhub/singleuser.py /usr/local/bin/jupyterhub-singleuser
RUN chmod 755 /usr/local/bin/jupyterhub-singleuser

RUN echo "data_scientist:{{ sudo_password }}" | chpasswd && \
    adduser data_scientist sudo

USER data_scientist

WORKDIR /home/data_scientist/

EXPOSE 8888 8200-8300

# set colors for terminal prompt
RUN echo 'export PS1="\e[1;34m\u@rpds \W$ \e[0m"' >> /home/data_scientist/.bashrc && \
    bash -c 'source /home/data_scientist/.bashrc'

ADD pyspark-notebook.py /home/data_scientist/.ipython/profile_default/startup/00-pyspark-notebook.py

ADD singleuser.sh /srv/singleuser/singleuser.sh

CMD ["sh", "/srv/singleuser/singleuser.sh"]
