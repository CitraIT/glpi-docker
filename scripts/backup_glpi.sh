#!/usr/bin/bash
#-------------------------------------------------------
# Citra IT - Excelencia em TI
# Script para backup do GLPI rodando em docker
# @author: luciano@citrait.com.br
# @data: 28/06/2026 @versao: 1.2
# o container glpi deve se chamar "glpi"
# o container do banco deve se chamar "mariadb"
# o nome do banco de dados, deve se chamar "glpi_dev"
# a senha do banco mysql deve ser "123456"
#-------------------------------------------------------

# parametros ajustaveis
DEST_DIR=/backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
DB_NAME="glpi_dev"
DB_PASS=123456
MANTER_VERSOES=7

# registra no log o inicio da operacao de backup
logger "iniciando backup do GLPI..."

# cria a pasta de backup caso não exista
mkdir $DEST_DIR 2>/dev/null

# exporta o banco de dados
docker exec -it mariadb mysqldump -p$DB_PASS --databases $DB_NAME > /backup/glpi_${TIMESTAMP}.sql

# compacta os arquivos www do glpi + config do apache
docker exec -it glpi tar -cf /tmp/GLPI_${TIMESTAMP}.tar \
        /var/www/html/glpi \
        /etc/apache2/sites-available

# copia o arquivo gerado dentro do container para o host
docker cp glpi:/tmp/GLPI_${TIMESTAMP}.tar /backup/

# adiciona o dump do mysql para o arquivo compactado
tar -rf /backup/GLPI_${TIMESTAMP}.tar /backup/glpi_${TIMESTAMP}.sql

# comprime o arquivo final para otimizar espaco
gzip /backup/GLPI_${TIMESTAMP}.tar

# removendo arquivos temporarios de dump do banco
rm -rf /backup/glpi_${TIMESTAMP}.sql


# removendo backups mais antigos que $MANTER_VERSOES
skip=0
ls -c $DEST_DIR | while read line; do
        skip=$(($skip + 1));
        if [ $skip -gt $MANTER_VERSOES ]; then
                logger "removendo backup antigo do glpi $line"
                rm -rf $DEST_DIR/$line
        fi
done

logger "finalizado operacao de backup do glpi"
