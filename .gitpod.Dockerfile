# Most of the stuff here are copied from the main Dockerfile, which tweaked to be worked in Debian way,
# which may need automation in the futur to keep things up-to-date.
FROM cljkondo/clj-kondo:2021.06.18-alpine as clj-kondo
FROM ghcr.io/assignuser/chktex-alpine:latest as chktex
FROM yoheimuta/protolint:latest as protolint
FROM ghcr.io/assignuser/lintr-lib:0.2.0 as lintr-lib
FROM ghcr.io/terraform-linters/tflint:latest as tflint
FROM checkmarx/kics:alpine as kics

# This image should be the last one to be used inside an workspace container. In this cause, we use an varation of
# the official Gitpod workspace image as the final image.
# Source Dockerfile: https://gitlab.com/gitpodify/gitpodified-workspace-images/-/blob/recaptime-dev-mainline/full/Dockerfile
FROM quay.io/gitpodified-workspace-images/full:latest as devenv-gitpod

ARG PWSH_VERSION='latest'
ARG ARM_TTK_NAME='master.zip'
ARG ARM_TTK_URI='https://github.com/Azure/arm-ttk/archive/master.zip'
ARG ARM_TTK_DIRECTORY='/opt/microsoft'
ARG DART_VERSION='2.8.4'
ARG PSSA_VERSION='latest'

RUN mkdir -p /home/gitpod/dotnet && curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel Current --install-dir /home/gitpod/dotnet
ENV DOTNET_ROOT=/home/gitpod/dotnet
ENV PATH=$PATH:/home/gitpod/dotnet

# Ignore npm package issues
RUN yarn config set ignore-engines true

# Python
RUN pip3 install --no-cache-dir --upgrade \
          'cpplint' \
          'cfn-lint' \
          'pylint' \
          'black' \
          'flake8' \
          'isort' \
          'bandit' \
          'mypy' \
          'restructuredtext_lint' \
          'rstcheck' \
          'sphinx<4.0' \
          'rstfmt' \
          'snakemake' \
          'snakefmt' \
          'sqlfluff' \
          'yamllint'

# npm - actually we're not in the root directory so we should be fine
RUN npm install --no-cache --ignore-scripts --global \
                sfdx-cli \
                typescript \
                asl-validator \
                @coffeelint/cli \
                jscpd@3.3.26 \
                secretlint@4.1.0 \
                @secretlint/secretlint-rule-preset-recommend@4.1.0 \
                stylelint \
                stylelint-config-standard \
                stylelint-config-sass-guidelines \
                stylelint-scss \
                dockerfilelint \
                editorconfig-checker \
                gherkin-lint \
                graphql-schema-linter \
                npm-groovy-lint \
                htmlhint \
                eslint \
                eslint-config-airbnb \
                eslint-config-prettier \
                eslint-config-standard \
                eslint-plugin-import \
                eslint-plugin-jest \
                eslint-plugin-node \
                eslint-plugin-prettier \
                eslint-plugin-promise \
                eslint-plugin-vue \
                babel-eslint \
                @babel/core \
                @babel/eslint-parser \
                standard@15.0.1 \
                prettier \
                jsonlint \
                eslint-plugin-jsonc \
                v8r@0.6.1 \
                eslint-plugin-react \
                eslint-plugin-jsx-a11y \
                markdownlint-cli \
                remark-cli \
                remark-preset-lint-recommended \
                markdown-link-check \
                markdown-table-formatter \
                @stoplight/spectral@5.6.0 \
                cspell \
                sql-lint \
                tekton-lint \
                prettyjson \
                @typescript-eslint/eslint-plugin \
                @typescript-eslint/parser

# Install packages from Homebrew as much as possible
RUN brew update; brew upgrade; \
    brew install actionlint terraform terrascan tflint

# Ruby
RUN bash -lc "echo 'gem: --no-document' >> ~/.gemrc && \
    gem install \
          scss_lint \
          puppet-lint \
          rubocop:0.82.0 \
          rubocop-github:0.16.0 \
          rubocop-performance:1.7.1 \
          rubocop-rails:2.5 \
          rubocop-rspec:1.41.0"

RUN sudo install-packages linux-headers-gcp
SHELL [ "/usr/bin/bash", "-o", "pipefail", "-lc" ]
RUN wget --tries=5 -q -O /tmp/phive.phar https://phar.io/releases/phive.phar \
    && wget --tries=5 -q -O /tmp/phive.phar.asc https://phar.io/releases/phive.phar.asc \
    && PHAR_KEY_ID="0x9D8A98B29B2D5D79" \
    && ( gpg --keyserver keyserver.pgp.com --recv-keys "$PHAR_KEY_ID" \
        || gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$PHAR_KEY_ID" \
        || gpg --keyserver pgp.mit.edu --recv-keys "$PHAR_KEY_ID" \
        || gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$PHAR_KEY_ID" ) \
    && gpg --verify /tmp/phive.phar.asc /tmp/phive.phar \
    && chmod +x /tmp/phive.phar \
    && sudo mv /tmp/phive.phar /usr/local/bin/phive \
    && rm /tmp/phive.phar.asc
# Powershell installation
SHELL [ "/usr/bin/bash", "-o", "pipefail", "-lc" ]
RUN curl --retry 5 --retry-delay 5 -s https://api.github.com/repos/powershell/powershell/releases/${PWSH_VERSION} \
        | grep browser_download_url \
        | grep powershell_ \
        | cut -d '"' -f 4 \
        | xargs -n 1 wget -O /tmp/powershell-deb-amd64.deb \
    && sudo dpkg -i /tmp/powershell-deb-amd64.deb \
    && rm /tmp/powershell-deb-amd64.deb
# SCALA installation
RUN sudo curl -fLo /usr/local/bin/coursier https://git.io/coursier-cli && \
    sudo chmod +x /usr/local/bin/coursier
# arm-ttk installation
ENV ARM_TTK_PSD1="${ARM_TTK_DIRECTORY}/arm-ttk-master/arm-ttk/arm-ttk.psd1"
RUN curl --retry 5 --retry-delay 5 -sLO "${ARM_TTK_URI}" \
    && sudo unzip "${ARM_TTK_NAME}" -d "${ARM_TTK_DIRECTORY}" \
    && sudo rm "${ARM_TTK_NAME}" \
    && sudo ln -sTf "${ARM_TTK_PSD1}" /usr/bin/arm-ttk \
    && sudo chmod a+x /usr/bin/arm-ttk
# bash-exec installation
RUN printf '#!/bin/bash \n\nif [[ -x "$1" ]]; then exit 0; else echo "Error: File:[$1] is not executable"; exit 1; fi' | sudo tee /usr/bin/bash-exec

# shfmt installation
ENV GO111MODULE=on
# Don't use go get, as per https://golang.org/doc/go-get-install-deprecation. Also I set GOPATH
# due to fact that /workspace directory is mounted when an workspace container in Gitpod starts.
RUN GOPATH=/home/gitpod/gopkgs go install mvdan.cc/sh/v3/cmd/shfmt@v3.3.1 \
   && echo "export PATH=\$PATH:/home/gitpod/gopkgs" | tee /home/gitpod/.bashrc.d/10-gopath-shfmt

# clj-kondo installation
COPY --from=clj-kondo /bin/clj-kondo /usr/bin/

# dotnet-format installation
RUN dotnet tool install -g dotnet-format

# dartanalyzer installation
RUN wget --tries=5 https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-x64-release.zip -O - -q | unzip -q - \
    && chmod +x dart-sdk/bin/dart* \
    && mv dart-sdk/bin/* /usr/bin/ && mv dart-sdk/lib/* /usr/lib/ && mv dart-sdk/include/* /usr/include/ \
    && rm -r dart-sdk/

# dotenv-linter installation
RUN wget -q -O - https://raw.githubusercontent.com/dotenv-linter/dotenv-linter/master/install.sh | sh -s

# golangci-lint installation
RUN wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh \
    && golangci-lint --version


# revive installation
RUN go get -u github.com/mgechev/revive

# checkstyle installation
RUN CHECKSTYLE_LATEST=$(curl -s https://api.github.com/repos/checkstyle/checkstyle/releases/latest \
        | grep browser_download_url \
        | grep ".jar" \
        | cut -d '"' -f 4) \
    && curl --retry 5 --retry-delay 5 -sSL $CHECKSTYLE_LATEST \
        --output /usr/bin/checkstyle


# ktlint installation
RUN curl --retry 5 --retry-delay 5 -sSLO https://github.com/pinterest/ktlint/releases/download/0.40.0/ktlint && \
    chmod a+x ktlint && \
    mv "ktlint" /usr/bin/


# kubeval installation
RUN wget -q https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz \
    && tar xf kubeval-linux-amd64.tar.gz \
    && cp kubeval /usr/local/bin


# chktex installation
COPY --from=chktex /usr/bin/chktex /usr/bin/
RUN cd ~ && touch .chktexrc

# luacheck installation
RUN wget --tries=5 https://www.lua.org/ftp/lua-5.3.5.tar.gz -O - -q | tar -xzf - \
    && cd lua-5.3.5 \
    && make linux \
    && make install \
    && cd .. && rm -r lua-5.3.5/ \
    && wget --tries=5 https://github.com/cvega/luarocks/archive/v3.3.1-super-linter.tar.gz -O - -q | tar -xzf - \
    && cd luarocks-3.3.1-super-linter \
    && ./configure --with-lua-include=/usr/local/include \
    && make \
    && make -b install \
    && cd .. && rm -r luarocks-3.3.1-super-linter/ \
    && luarocks install luacheck


# perlcritic installation
RUN curl --retry 5 --retry-delay 5 -sL https://cpanmin.us/ | perl - -nq --no-wget Perl::Critic

# phpcs installation
RUN phive --no-progress install phpcs -g --trust-gpg-keys 31C7E470E2138192


# phpstan installation
RUN phive --no-progress install phpstan -g --trust-gpg-keys CF1A108D0E7AE720


# psalm installation
RUN phive --no-progress install psalm -g --trust-gpg-keys 8A03EA3B385DBAA1,12CE0F1D262429A5


# phplint installation
RUN composer global require overtrue/phplint ^3.0 \
    && composer global config bin-dir --absolute

ENV PATH="/root/.composer/vendor/bin:$PATH"

# powershell installation
RUN pwsh -c 'Install-Module -Name PSScriptAnalyzer -RequiredVersion ${PSSA_VERSION} -Scope AllUsers -Force'

# protolint installation
COPY --from=protolint /usr/local/bin/protolint /usr/bin/

# lintr installation
COPY --from=lintr-lib /usr/lib/R/library/ /home/r-library
RUN R -e "install.packages(list.dirs('/home/r-library',recursive = FALSE), repos = NULL, type = 'source')"

# raku installation
RUN curl -1sLf 'https://dl.cloudsmith.io/public/nxadm-pkgs/rakudo-pkg/gpg.0DD4CA7EB1C6CC6B.key' | gpg --dearmor | sudo tee /usr/share/keyrings/rakudo-pkg-archive.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/rakudo-pkg-archive.gpg] https://dl.cloudsmith.io/public/nxadm-pkgs/rakudo-pkg/deb/ubuntu focal main" | sudo tee /etc/apt/sources.d/rakudo-pkg.list >>/dev/null \
    && echo "deb-src [/usr/share/keyrings/rakudo-pkg-archive.gpg] https://dl.cloudsmith.io/public/nxadm-pkgs/rakudo-pkg/deb/ubuntu focal main"| sudo tee /etc/apt/sources.d/rakudo-pkg.list >> /dev/null \
    && sudo install-packages rakudo-pkg

ENV PATH="~/.raku/bin:/opt/rakudo-pkg/bin:/opt/rakudo-pkg/share/perl6/site/bin:$PATH"

# clippy installation
RUN rustup component add clippy

# sfdx-scanner-ape, sfdx-scanner-lwc and sfdx-scanner-lwc installation
RUN sfdx plugins:install @salesforce/sfdx-scanner \
    && sfdx plugins:install @salesforce/sfdx-scanner \
    && sfdx plugins:install @salesforce/sfdx-scanner
    
# scalafix installation
RUN coursier install scalafix --quiet --install-dir /usr/bin

# misspell installation
RUN curl -L -o /tmp/install-misspell.sh https://git.io/misspell \
    && sh /tmp/install-misspell.sh; rm /tmp/install-misspell.sh

# tsqllint installation
RUN dotnet tool install --global TSQLLint

# terrascan setup
RUN terrascan init

# checkov installation
RUN pip3 install --upgrade --no-cache-dir pip && pip3 install --upgrade --no-cache-dir setuptools \
    && pip3 install --no-cache-dir checkov

# kics installation
COPY --from=kics /app/bin/kics /usr/bin/
RUN mkdir -p /opt/kics/assets
ENV KICS_QUERIES_PATH=/opt/kics/assets/queries KICS_LIBRARIES_PATH=/opt/kics/assets/libraries
COPY --from=kics /app/bin/assets /opt/kics/assets/
