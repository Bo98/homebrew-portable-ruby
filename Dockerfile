ARG img=debian/eol:wheezy
# hadolint ignore=DL3006
FROM ${img}
ARG img
ARG bootstrap_ruby

RUN uname -a

ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH \
    HOMEBREW_DEVELOPER=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1

RUN if [ ${img} = "resin/rpi-raspbian:wheezy" ]; then \
      sed -i 's/archive.raspbian.org/legacy.raspbian.org/g' /etc/apt/sources.list; \
    fi

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      file \
      g++ \
      git-core \
      locales \
      make \
      patch \
      procps \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && if [ -n "${bootstrap_ruby}" ]; then \
      gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB \
      && curl -L https://get.rvm.io | bash -s stable --ruby="${bootstrap_ruby}"; \
    fi

# ENV PATH=/usr/local/rvm/wrappers/default:$PATH
# hack hack hack -- remove!!
RUN ln -s /usr/local/rvm/wrappers/default/ruby /usr/bin/ruby

# hadolint ignore=DL3059
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && useradd -m -s /bin/bash linuxbrew

# hadolint ignore=DL3059
RUN git clone --depth=1 https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew \
    && git clone --depth=1 https://github.com/Homebrew/linuxbrew-core /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/homebrew-core \
    && mkdir /home/linuxbrew/.linuxbrew/bin \
    && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/ \
    && brew tap homebrew/portable-ruby
