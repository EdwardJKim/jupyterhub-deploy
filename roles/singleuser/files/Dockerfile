# Build as jupyter/jupyterhub-singleuser
# Run with the DockerSpawner in JupyterHub

FROM ipython/scipystack

MAINTAINER IPython Project <ipython-dev@scipy.org>

RUN apt-get update && \
    apt-get install -y -q \
    vim \
    wget \
    gfortran \ # need fortran compiler to install pymc
    ttf-liberation \ # fonts needed in seaborn
    ttf-bitstream-vera 
 
RUN pip3 install traitlets

# fetch juptyerhub-singleuser entrypoint
ADD https://raw.githubusercontent.com/jupyter/jupyterhub/master/jupyterhub/singleuser.py /usr/local/bin/jupyterhub-singleuser
RUN chmod 755 /usr/local/bin/jupyterhub-singleuser

# jupyter is our user
RUN useradd -m -u 1000 -s /bin/bash data_scientist

USER data_scientist
ENV HOME /home/data_scientist
ENV SHELL /bin/bash
ENV USER data_scientist

WORKDIR /home/data_scientist/

# IPython introductions
RUN cp -r /srv/ipython/examples /home/data_scientist/examples

EXPOSE 8888

# set colors for terminal prompt
RUN echo 'export PS1="\e[1;34m\u@\h:\w$ \e[0m"' >> /home/data_scientist/.bashrc

ADD singleuser.sh /srv/singleuser/singleuser.sh

CMD ["sh", "/srv/singleuser/singleuser.sh"]
