FROM debian:12

# Não faça perguntas na instalação
ENV DEBIAN_FRONTEND noninteractive

#Instalação dos pré-requisitos
RUN apt update && \
	apt install --yes --no-install-recommends \
	git \
	curl \
	unzip \
	cron \
	wget \
	ca-certificates \
	jq \
	apache2 \
	php8.2 \
	php8.2-mysql \
	php8.2-ldap \
	php8.2-xmlrpc \
	php8.2-imap \
	php8.2-curl \
	php8.2-gd \
	php8.2-mbstring \
	php8.2-xml \
	php8.2-apcu \
	php-cas \
	php8.2-intl \
	php8.2-zip \
	php8.2-bz2 \
	libapache2-mod-php8.2 \
	libldap-2.5-0 \
	libldap-common \
	libsasl2-2 \
	libsasl2-modules \
	libsasl2-modules-db \
	&& rm -rf /var/lib/apt/lists/*


# Instala o composer necessário para alguns plugins
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copia o entrypoint do projeto para o container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Sanitiza o entrypoint removendo carrige return (CR)
RUN sed -i -e 's/\r$//' /entrypoint.sh

# Declara o entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Expoe a porta do apache
EXPOSE 80

