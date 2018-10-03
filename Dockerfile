FROM ubuntu:xenial
LABEL maintainer="bry.psi@gmail.com"

ARG P2POOL_VERSION
ARG HOME
ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID

# add env with specified (or default) values
ENV P2POOL_VERSION ${P2POOL_VERSION:-62fa7b020b82a92138d7652c26be2953b26fd4e5}
ENV HOME ${HOME:-/app}
ENV USER_NAME ${USER_NAME:-p2pool}
ENV GROUP_NAME ${GROUP_NAME:-p2pool}
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -g $GROUP_ID $GROUP_NAME \
	&& useradd -u $USER_ID -g $GROUP_NAME -s /bin/bash -m -d $HOME $USER_NAME && \
	chown -R $USER_NAME:$GROUP_NAME $HOME

# add scripts to local bin directory
COPY docker-entrypoint.sh btc_oneshot btc_init /usr/local/bin/

# libboost-all-dev 
# add repo key for bitcoin and install needed packages
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C70EF1F0305A1ADB9986DBD8D46F45428842CE5E && \
    echo "deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main" > /etc/apt/sources.list.d/bitcoin.list && \
	apt-get update && apt-get install --no-install-recommends -y \ 
	python-twisted python-argparse python-pip git \
	build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev

# build bitcoind
RUN cd /tmp && \
	git clone -b 0.15 https://github.com/bitcoin/bitcoin.git && \
	cd /tmp/bitcoin && \ 
	./autogen.sh && \
	./configure && \	
	make install

# install p2pool
RUN cd $HOME && \
	git clone https://github.com/p2pool/p2pool.git && \
    cd $HOME/p2pool && git reset --hard $P2POOL_VERSION && \    
    echo "service_identity" >> requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# install extended gui	
RUN cd $HOME/p2pool && \
	mv web-static web-static-original && \
	git clone https://github.com/hardcpp/P2PoolExtendedFrontEnd.git && \
	ln -s P2PoolExtendedFrontEnd web-static			

# clean up
RUN	apt-get remove --purge -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*	

# make sure the volumes permissions are set correctly
RUN mkdir -p $HOME/p2pool/data && \
	chown -R $USER_NAME:$GROUP_NAME $HOME/p2pool/data && \
	chmod -R 775 $HOME/p2pool/data && \
	mkdir -p $HOME/.bitcoin/ && \
	chown -R $USER_NAME:$GROUP_NAME $HOME/.bitcoin

# add the volumes
VOLUME ["$HOME/.bitcoin", "$HOME/p2pool/data"]

USER $USER_NAME
EXPOSE 9332 9333 8332 8333 18332 18333
WORKDIR $HOME

ENTRYPOINT ["docker-entrypoint.sh"]