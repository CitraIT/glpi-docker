#!/bin/bash
#-------------------------------------------------------------------------------------
# CITRAIT - EXCELENCIA EM TI
# GLPI Docker Deployment
# @Version: 1.0
# @Author: luciano@citrait.com.br
# @Description: Deploy GLPI application using docker-compose
# Compatible with glpi 10.0.5+
#-------------------------------------------------------------------------------------
# Ref.: https://faq.teclib.com/03_knowledgebase/procedures/install_glpi/#how-to-create-a-virtualhost-dedicated-to-glpi


#-------------------------------------------------------------------------------------
#
#                          VARIAVEIS AUXILIARES
#
#-------------------------------------------------------------------------------------
FOLDER_GLPI=glpi/
FOLDER_WEB=/var/www/html/
LOCAL_GLPI_VERSION=$(ls ${FOLDER_WEB}/${FOLDER_GLPI}/version 2>/dev/null)
SRC_GLPI=https://github.com/glpi-project/glpi/releases/download/${VERSION_GLPI}/glpi-${VERSION_GLPI}.tgz
TAR_GLPI=glpi-${VERSION_GLPI}.tgz
PLUGIN_SINGLESIGNON_SRC=https://github.com/edgardmessias/glpi-singlesignon/releases/download/v1.3.3/singlesignon.tgz
PLUGIN_ESCALADE_SRC=https://github.com/pluginsGLPI/escalade/archive/refs/tags/2.9.4.tar.gz
PLUGIN_ITILCATEGORYGROUPS_SRC=https://github.com/pluginsGLPI/itilcategorygroups/archive/refs/tags/2.5.1.tar.gz
PLUGIN_TREEVIEW_SRC=https://github.com/pluginsGLPI/treeview/archive/refs/tags/1.10.2.tar.gz
PLUGIN_TIMELINETICKET_SRC=https://github.com/pluginsGLPI/timelineticket/archive/refs/tags/10.0+1.2.tar.gz
PLUGIN_ADDITIONALALERTS_SRC=https://github.com/InfotelGLPI/additionalalerts/archive/refs/tags/2.4.0.tar.gz
PLUGIN_OAUTHIMAP_SRC=https://github.com/pluginsGLPI/oauthimap/archive/refs/tags/1.4.3.tar.gz
PLUGIN_MORETICKET_SRC=https://github.com/InfotelGLPI/moreticket/archive/refs/tags/1.7.4.tar.gz
PLUGIN_SATISFACTION_SRC=https://github.com/pluginsGLPI/satisfaction/archive/refs/tags/1.6.2.tar.gz



#-------------------------------------------------------------------------------------
#
#                          FUNÇÕES AUXILIARES
#
#-------------------------------------------------------------------------------------

# Registra na tela o evento com carimbo de data/hora
function log(){
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1";
}

# Corrige as permissoes da pasta do GLPI no diretório web
function glpi_fix_perms(){
	log "fixing glpi folder permissions..."
	chown -R  www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}
	chown www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}marketplace -Rf
	find ${FOLDER_WEB}${FOLDER_GLPI} -type f -exec chmod 0644 {} \;
	find ${FOLDER_WEB}${FOLDER_GLPI} -type d -exec chmod 0755 {} \;
	chmod +x ${FOLDER_WEB}${FOLDER_GLPI}front/cron.php
}

# Realiza o download e extração do source do glpi para a devida pasta
# Obs.: irá sobrescrever a pasta atual do GLPI
function glpi_download_and_extract_source(){
	log "downloading and extracting glpi..."
	wget -q -P ${FOLDER_WEB} ${SRC_GLPI}
	tar -xzf ${FOLDER_WEB}${TAR_GLPI} -C ${FOLDER_WEB}
	rm -Rf ${FOLDER_WEB}${TAR_GLPI}
}

# Remove a pasta "install" do glpi
function glpi_remove_install_folder(){
	log "removing glpi install folder..."
	rm -rf ${FOLDER_WEB}${FOLDER_GLPI}install
}


# Realiza a instalação do schema do banco de dados (e também define os dados de acesso ao banco)
function glpi_install_db(){
	log "installing glpi database schema..."
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console db:install --db-host=${DB_HOST} --db-port=${DB_PORT} --db-name=${DB_DATABASE} --db-user=${DB_USER} --db-password=${DB_PASSWORD} --no-interaction -vv
}


# Ajusta os dados de conexão com o banco de dados
function glpi_configure_db(){
	log "configuring glpi database parameters..."
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console db:configure --db-host=${DB_HOST} --db-port=${DB_PORT} --db-name=${DB_DATABASE} --db-user=${DB_USER} --db-password=${DB_PASSWORD} --reconfigure --no-interaction --no-plugins -vv
}


# Ajusta os dados de conexão com o banco de dados
function glpi_update_db_schema(){
	log "updating glpi database schema..."
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console database:update --no-interaction --skip-db-checks --no-plugins -vv
}


# Executa as migrations do banco do GLPI
function glpi_db_execute_migrations(){
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console migration:migrate_all --no-interaction --no-plugins -vv
	
}

# Testa se o banco de dados está com status OK
function glpi_test_database_ok(){
	log "verifying if glpi database is in ok state..."
	if [[ "$(php ${FOLDER_WEB}${FOLDER_GLPI}bin/console system:status --format json | jq .db.status)" == '"OK"' ]];
		then
			return 0
		else
			return 1
		fi
	
}


# Configura o timezone conforme o env
function php_setup_timezone(){
	log "setting up TIMEZONE..."
	if [[ -z "${TIMEZONE}" ]];
	then 
		log "TIMEZONE is unset";
	else
		PHPVER=$(php -i | grep 'Loaded Configuration' | awk '{print $5}' | cut -d/ -f4)
		echo "date.timezone = \"$TIMEZONE\"" > /etc/php/${PHPVER}/apache2/conf.d/timezone.ini
		echo "date.timezone = \"$TIMEZONE\"" > /etc/php/${PHPVER}/cli/conf.d/timezone.ini
	fi
}


# Configura o parâmetro cookie httponly do php conforme requisito
function php_setup_cookiehttponly(){
	log "setting up php cookie http-only..."
	PHPVER=$(php -i | grep 'Loaded Configuration' | awk '{print $5}' | cut -d/ -f4)
	echo "session.cookie_httponly = on" > /etc/php/${PHPVER}/apache2/conf.d/20-cookionly.ini
}



# Lê para environment a versão do glpi atualmente instalada via arquivo .version
function export_glpi_version(){
	log "detecting glpi installed version..."
	if [ -d ${FOLDER_WEB}${FOLDER_GLPI}version ];
	then
		export LOCAL_GLPI_VERSION=$(ls ${FOLDER_WEB}/${FOLDER_GLPI}/version)
	else
		export LOCAL_GLPI_VERSION=$(ls ${FOLDER_WEB}/${FOLDER_GLPI}/.version)
	fi
}


# Instala plugin no GLPI
function glpi_install_supported_plugin(){
	PLUGIN_NAME=$1
	PLUGIN_SRC=$2
	if [ ! -d ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME} ];
	then
		log "installing plugin ${PLUGIN_NAME}..."
		
		PLUGIN_DOWNLOADED_FILENAME=$(basename ${PLUGIN_SRC})
		wget -q -P ${FOLDER_WEB}${FOLDER_GLPI}marketplace/ ${PLUGIN_SRC}
		tar -xzf ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_DOWNLOADED_FILENAME} -C ${FOLDER_WEB}${FOLDER_GLPI}marketplace/
		# fix para remover '+' no nome do arquivo em algins plugins...
		TMP_NAME=${PLUGIN_NAME}-${PLUGIN_DOWNLOADED_FILENAME/.tar.gz/}
		TMP_NAME=${TMP_NAME/+/-}
		mv ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${TMP_NAME} ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME}
		rm -Rf ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_DOWNLOADED_FILENAME}
		
		# Precisa rodar o composer?
		if [ -f ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME}/composer.json ];
		then
			cd ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME} && composer install --no-dev
		fi
	fi
}


# Desabilita temporariamente os plugins (todos)
function glpi_disable_all_plugins(){
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console plugin:deactivate -a --no-interaction -vv
}
	
	
	
# Habilita os plugins (todos) novamente
function glpi_enable_all_plugins(){
	php ${FOLDER_WEB}${FOLDER_GLPI}bin/console plugin:activate -a --no-interaction -vv
}





#-------------------------------------------------------------------------------------
#
#                          ROTINA PRINCIPAL DO SCRIPT
#
#-------------------------------------------------------------------------------------

#======================================================================================
#
# Setup Configurações PHP
#
#======================================================================================
# Configura timezone php
php_setup_timezone

# Configura cookie http-only do php
php_setup_cookiehttponly


#======================================================================================
#
# Verifica se é a primeira instalação ou upgrade de versão
#
#======================================================================================
# Testa se o GLPI está atualmente instalado, consultando se existe a pasta do sistema
log "checking for GLPI already installed..."
if [[ ! -f ${FOLDER_WEB}${FOLDER_GLPI}index.php ]];
then
	##################   INSTALAÇÃO DO GLPI NÃO ENCONTRADA - REALIZANDO UMA DO ZERO ###############
	log "no GLPI installation found. installing a new instance..."
	
	# Download do codigo do glpi
	glpi_download_and_extract_source
	
	# Instala o schema do banco de dados, já informando os dados de acesso
	glpi_install_db
	
	# Remove o diretório de setup inicial
	glpi_remove_install_folder
	
	# Verifica se o banco está com status OK
	glpi_test_database_ok
	if [[ $? -eq 0 ]];
	then
		log "GLPI Installed successfully!"
		# lê novamente a versão do glpi no disco após upgrade
		export_glpi_version
	else
		log "GLPI database setup error. Please check the logs for more information."
		exit -1
	fi
else
	##################   INSTALAÇÃO DO GLPI EXISTENTE - UPGRADE NECESSÁRIO (??) ###############
	log "GLPI installation found. detecting if upgraded needed"
	
	# Testa a versão atualmente instalada para detectar o upgrade
	export_glpi_version
	if [[ "$LOCAL_GLPI_VERSION" == "$VERSION_GLPI" ]];
	then
		log "GLPI Installed version ${LOCAL_GLPI_VERSION} running as ENV No upgrade needed."
		log "flight check ok."
	else
		##################   INSTALAÇÃO DO GLPI EXISTENTE - REALIZANDO UPGRADE ###############
		log "GLPI mismatch version between ENV ('${VERSION_GLPI}') and .version ('${LOCAL_GLPI_VERSION}') file. performing upgrade..."
		
		# Fix para chave faltando.
		# para não causar dependencia circular, deve vir antes do upgrade do código...
		if [ ! -f ${FOLDER_WEB}${FOLDER_GLPI}config/glpicrypt.key ];
		then
			log "GLPI missing config/glpicrypt.key file. trying to recreating it..."
			php ${FOLDER_WEB}${FOLDER_GLPI}bin/console glpi:security:change_key --no-interaction -vv
			if [ ! -f ${FOLDER_WEB}${FOLDER_GLPI}config/glpicrypt.key ];
			then
				log "file config/glpicrypt.key not regenerated successfully. creating a generic one."
				echo -n "l6+EYDLwTwLpMvkhKaZ8jFiPaQ3mnXqO5+eqey3oxrE=" | base64 -d > ${FOLDER_WEB}${FOLDER_GLPI}config/glpicrypt.key
			fi
		fi
		
		# Gera novamente os parametros de conexões com o banco conforme o ENV
		glpi_configure_db
		
		# Fix: remove arquivos .version de versoes anteriores
		# [REQUIRED] Previous GLPI version files detection    | [ERROR]    | We detected files of previous versions of GLPI.
		log "removing old version reference file..."
		if [[ -d ${FOLDER_WEB}${FOLDER_GLPI}.version ]];
		then
			rm -rf ${FOLDER_WEB}${FOLDER_GLPI}.version
		fi
		if [[ -d ${FOLDER_WEB}${FOLDER_GLPI}version ]];
		then
			rm -rf ${FOLDER_WEB}${FOLDER_GLPI}version
		fi
		
		# Download do codigo do glpi
		glpi_download_and_extract_source
		
		# executar upgrade do schema do banco
		glpi_update_db_schema
		
		# Desabilita os plugins para executar upgrade de schema no banco.
		glpi_disable_all_plugins
		
		# Realiza upgrade das tabelas (migrations)
		glpi_db_execute_migrations
		
		# Verifica se o banco está com status OK
		glpi_test_database_ok
		if [[ $? -eq 0 ]];
		then
			log "GLPI Installed successfully!"
			# lê novamente a versão do glpi no disco após upgrade
			export_glpi_version
			
			# Remove o diretório de setup inicial
			glpi_remove_install_folder
			
			export UPGRADE_SUCCESS="yes"
		else
			log "GLPI database error after upgrade procedure. Please check the logs for more information."
			exit -1
		fi
	fi
fi



		


#======================================================================================
#
#     Instalação de Plugins
#
#======================================================================================
# PLUGIN: singlesignon - não é oficialmente suportado e precisa de instlação manual...
PLUGIN_NAME=singlesignon
if [ ! -d ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME} ];
then
	log "installing plugin ${PLUGIN_NAME}..."
	git clone https://github.com/virtazp/GLPI-Azure-SSO.git /tmp/GLPI-Azure-SSO
	mv /tmp/GLPI-Azure-SSO/${PLUGIN_NAME} ${FOLDER_WEB}${FOLDER_GLPI}marketplace/${PLUGIN_NAME}
	rm -Rf /tmp/GLPI-Azure-SSO
	
	# fix para plugin singlesigon funcionar com o novo marketplace de plugins do glpi.
	sed -i 's/\/plugins\//\/marketplace\//' ${FOLDER_WEB}${FOLDER_GLPI}marketplace/singlesignon/inc/toolbox.class.php
fi

# PLUGIN: escalade
glpi_install_supported_plugin escalade ${PLUGIN_ESCALADE_SRC}

# PLUGIN: itilcategorygroups
glpi_install_supported_plugin itilcategorygroups ${PLUGIN_ITILCATEGORYGROUPS_SRC}

# PLUGIN: treeview
glpi_install_supported_plugin treeview ${PLUGIN_TREEVIEW_SRC}

# PLUGIN: timelineticket
glpi_install_supported_plugin timelineticket ${PLUGIN_TIMELINETICKET_SRC}

# PLUGIN: additionalalerts
glpi_install_supported_plugin additionalalerts ${PLUGIN_ADDITIONALALERTS_SRC}

# PLUGIN: oauthimap
glpi_install_supported_plugin oauthimap ${PLUGIN_OAUTHIMAP_SRC}

# PLUGIN: moreticket
glpi_install_supported_plugin moreticket ${PLUGIN_MORETICKET_SRC}

# PLUGIN: satisfaction
glpi_install_supported_plugin satisfaction ${PLUGIN_SATISFACTION_SRC}


# Re-habilita os plugins após um upgrade bem sucedido
if [ -n ${UPGRADE_SUCCESS} ];
then
	log "enabling all plugins again..."
	glpi_enable_all_plugins
fi



#======================================================================================
#
# Permissões de pastas e arquivos
#
#======================================================================================
# Corrige permissões do diretório da aplicação
glpi_fix_perms




#======================================================================================
#
# Configuração do WebServer Apache
#
#======================================================================================
# Verifica se a versão > 10.0.7 para configurar o apache adequadamente
LOCAL_GLPI_MAJOR_VERSION=$(echo $LOCAL_GLPI_VERSION | cut -d. -f1)
LOCAL_GLPI_VERSION_NUM=${LOCAL_GLPI_VERSION//./}
TARGET_GLPI_VERSION="10.0.7"
TARGET_GLPI_VERSION_NUM=${TARGET_GLPI_VERSION//./}
TARGET_GLPI_MAJOR_VERSION=$(echo $TARGET_GLPI_VERSION | cut -d. -f1)

# Cria a configuração virtualhost do apache2, conforme a versão do glpi
if [[ $LOCAL_GLPI_VERSION_NUM -lt $TARGET_GLPI_VERSION_NUM || $LOCAL_GLPI_MAJOR_VERSION -lt $TARGET_GLPI_MAJOR_VERSION ]]; 
then
	log "Gererating apache2 config for glpi < 10.0.7"
	cat << EOF > /etc/apache2/sites-available/000-default.conf
	<VirtualHost *:80>
		DocumentRoot ${FOLDER_WEB}${FOLDER_GLPI}
		<Directory ${FOLDER_WEB}${FOLDER_GLPI}>
			Require all granted
			RewriteEngine On
			RewriteCond %{REQUEST_FILENAME} !-f
			RewriteRule ^(.*)$ index.php [QSA,L]
		</Directory>
		ErrorLog /var/log/apache2/error.log
		LogLevel warn
		CustomLog /var/log/apache2/access.log combined
	</VirtualHost>
EOF
else
	echo "Gererating apache2 config for glpi >= 10.0.7"
	cat << EOF > /etc/apache2/sites-available/000-default.conf
	<VirtualHost *:80>
		DocumentRoot ${FOLDER_WEB}${FOLDER_GLPI}public
		<Directory ${FOLDER_WEB}${FOLDER_GLPI}public>
			Require all granted
			RewriteEngine On
			# Ensure authorization headers are passed to PHP.
			# Some Apache configurations may filter them and break usage of API, CalDAV, ...
			RewriteCond %{HTTP:Authorization} ^(.+)$
			RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
			# Redirect all requests to GLPI router, unless the file exists.
			RewriteCond %{REQUEST_FILENAME} !-f
			RewriteRule ^(.*)$ index.php [QSA,L]
		</Directory>
		ErrorLog /var/log/apache2/error.log
		LogLevel warn
		CustomLog /var/log/apache2/access.log combined
	</VirtualHost>
EOF
fi

# Habilita o módulo rewrite do apache2
log "apache2 rewrite habilitado"
a2enmod rewrite


#======================================================================================
#
# Tarefas Cron
#
#======================================================================================
# Cria a tarefa cron para executar as rotinas automáticas
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi

# Inicia serviço cron
service cron start




#======================================================================================
#
# Fligh Check OK - Iniciar o Apache2
#
#======================================================================================
#Inicie o serviço apache em primeiro plano
/usr/sbin/apache2ctl -D FOREGROUND