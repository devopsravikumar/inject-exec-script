   docker_live_image=c7-sentinel16
   docker_live_version=1.0.0.0
   privatehub=docker-hub-dev.blueally.com
   hubuid=bachdocker
   hubpwd=Li0nIa2020
   sentinel_hostname=docker-brownbag
   sentinel_name=docker-brownbag
   sentinel_IP=
   jwt_token=eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIxMjM0NTYiLCJhdWQiOiJUZXN0Q3VzdG9tZXIiLCJpYXQiOjE1NTIzOTQ3MjUsImlzcyI6InNhZmVndWFyZC5ibHVlYWxseS5jb20iLCJleHAiOjE1NTI1Njc1MjV9.TArK55dODZ_eW5kmuxdVFDsaHWcSwg8ceaxLGvcFPIG9Buzs_43bIJ_NSHtZbhzyhmYXo193UsUDYqYlvjnd1g
   registration_key=1WOhY9p7rFBO7YpXeeOjh5AqTDzlctph
   security_key=123456
   customer_name="Customer1"
   gateway_url=https://bach-gw002.blueally.com:8080
   rest_api_url=https://safeguard.blueally.com/sentry
   rest_api_url_show=`echo "$rest_api_url" | awk -F/ '{ print $1$3 }'| sed 's#:#://#g' `
   gateway_urls=https://bach-gw002.blueally.com:8080
   gateway_url_show=`echo "$gateway_url" | awk -F: '{ print $1":"$2}'`

   updateHostentry () {
   docker exec -it $sentinel_name bash -c '/usr/bin/echo "49.249.253.256   bach-gw002.blueally.com bach-gw002" >> /etc/hosts'
   docker exec -it $sentinel_name bash -c '/usr/bin/echo "182.72.201.256  bach-gw001.blueally.com bach-gw001" >> /etc/hosts'
   docker exec -it $sentinel_name bash -c '/usr/bin/echo "10.4.1.256    sg-dev.blueally.com  sg-dev" >> /etc/hosts'
   }
   mapports="-p 85:22 -p 514:514 -p 514:514/udp -p 1514:1514 -p 1514:1514/udp -p 162:162 -p 2055:2055 -p 2055:2055/udp -p 6343:6343 -p 6343:6343/udp -p 6344:6344 -p 6344:6344/udp -p 6514:6514 -p 6514:6514/udp -p 45000:45000/udp  -p 30:25 -p 7473:7473"
   # echo "Pull docker image from HUB"
   # docker pull $privatehub/$docker_live_image:$docker_live_version

   echo "Initializing Sentinel image....."

   docker run -h $sentinel_hostname -d $mapports -v /data/$sentinel_name/nifi/config/dmidecode:/usr/sbin/dmidecode -v /data/$sentinel_name/nifi/logs:/opt/nifi/logs -v /data/$sentinel_name/nifi/flowfile_repository:/opt/nifi/flowfile_repository -v /data/$sentinel_name/nifi/database_repository:/opt/nifi/database_repository -v /data/$sentinel_name/nifi/content_repository:/opt/nifi/content_repository -v /data/$sentinel_name/nifi/provenance_repository:/opt/nifi/provenance_repository -v /data/$sentinel_name/VulnWhisperer/data:/opt/VulnWhisperer/data --name $sentinel_name -it --restart always $privatehub/$docker_live_image:$docker_live_version
   #updated uuid in flow.xml and gzip the file

   myuuid=$(dmidecode | grep UUID | awk -F": " '{print $2}')

   ## echo "Proposed UUID $myuuid"
   #echo ' echo "   UUID:  '${myuuid}'"' > /data/$sentinel_name/nifi/config/dmidecode

   ## REST_END_POINT_URL
   PORTAL_SCAN_URL=${rest_api_url}/api/v1/nifi/sentinel/$myuuid
   # echo ${PORTAL_SCAN_URL}
   PORTAL_SCAN_URL=${rest_api_url_show}

   docker exec -it $sentinel_name bash -c 'mkdir /opt/VulnWhisperer/data/nessus; mkdir /opt/VulnWhisperer/data/openvas; mkdir /opt/VulnWhisperer/data/database; mkdir "/opt/VulnWhisperer/data/nessus/My Scans";'

   docker exec -it $sentinel_name bash -c 'cd /opt/nifi/conf && /usr/bin/gunzip flow.xml.gz && sed -i "s#value=\"PORTAL_SCAN_URL\"#value=\"'${PORTAL_SCAN_URL}'\"#g" /opt/nifi/conf/flow.xml && /usr/bin/gzip flow.xml'
   docker exec -it $sentinel_name bash -c 'cd /opt/nifi/conf && /usr/bin/gunzip flow.xml.gz && sed -i "s#value=\"MYSENTINELUUID\"#value=\"'${myuuid}'\"#g" /opt/nifi/conf/flow.xml && /usr/bin/gzip flow.xml'


   docker exec -it $sentinel_name bash -c 'cd /opt/nifi/conf && /usr/bin/gunzip flow.xml.gz && sed -i "s#<value>ED4707F3-361D-9130-7B33-93853D25A132</value>#<value>"'$myuuid'"</value>#g" /opt/nifi/conf/flow.xml && /usr/bin/gzip flow.xml'

   # Updating GatewayUrls
   docker exec -it $sentinel_name bash -c 'cd /opt/nifi/conf && /usr/bin/gunzip flow.xml.gz && sed -i "s#<url>\$GATEWAY_URL\$</url>#<url>"'$gateway_url/nifi'"</url>#" /opt/nifi/conf/flow.xml && sed -i "s#<urls>\$GATEWAY_URLS\$</urls>#<urls>"'$gateway_urls'"</urls>#" /opt/nifi/conf/flow.xml && /usr/bin/gzip flow.xml'

   #update sentienl name in nifi.properties
   docker exec -it $sentinel_name sed -i 's#nifi.ui.banner.text=.*#nifi.ui.banner.text='$sentinel_name'#' /opt/nifi/conf/nifi.properties

   # Function to update hostentry
   updateHostentry

   # Restart nifi
   docker exec -it $sentinel_name bash -c 'cd /opt/nifi/bin && ./nifi.sh stop && sleep 10 && ./nifi.sh start' >/dev/null
   #docker exec -it $sentinel_name bash -c 'cd /opt/nifi/bin && ./nifi.sh status &'



   # Updating the sentinel process check
   cp -f ${SCRIPTDIR}/sentineld /data/
   chmod 755 /data/sentineld
   # make cron entry
   dt=`date +%d-%m-%Y_%H_%m_%S`
   isCronentry=`crontab -l 2> /dev/null | grep -i sentineld |grep -v grep | wc -l`
   if [ "${isCronentry}" == "0" ]; then
        crontab -l > /var/log/cron_${dt}.bkp 2> /dev/null
        crontab -l > /tmp/a.cron 2> /dev/null
        echo "*/15 * * * * /bin/sh /data/sentineld check > /tmp/sentineld.check.out" >> /tmp/a.cron
        crontab /tmp/a.cron 2> /dev/null
        rm -f /tmp/a.cron
   else
        crontab -l > /var/log/cron_${dt}.bkp 2> /dev/null
        crontab -l | grep -v sentineld > /tmp/a.cron 2> /dev/null
        echo "*/15 * * * * /bin/sh /data/sentineld check > /tmp/sentineld.check.out" >> /tmp/a.cron
        crontab /tmp/a.cron 2> /dev/null
        rm -f /tmp/a.cron
   fi


   ## sentinel_IP=`hostname -i | awk '{print $1 }'`
   ## sentinel_IP=`hostname -i 2> /dev/null | awk '{print $1 }'`
        sentinel_IP=`ip a | grep -w "inet" | grep -v 127.0.0.1 | awk '{print $2}' | cut -d"/" -f1 | head -1`
   if [ "$sentinel_IP"  == "" ] ; then
        sentinel_IP=`hostname -iI 2> /dev/null | awk '{print $1 }'`
   fi

        dkr_sentinel_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $sentinel_name`
   if [ "$dkr_sentinel_IP"  == "" ] ; then
        dkr_sentinel_IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $sentinel_name`
   fi

   SIEMDIR="/data"
   if [ ! -d "$SIEMDIR" ]; then
        mkdir /data 2> /dev/null
        # echo "SENTINEL not exit $sentinel_name"
   fi
   echo "SENTINEL=$sentinel_name" > /data/.sentinel
   echo "CUSTOMER=$customer_name" >> /data/.sentinel
   echo "HOSTIP=$sentinel_IP" >> /data/.sentinel
   echo "GATEWAYURLS=$gateway_urls" >> /data/.sentinel
   echo "GATEWAYURL=$gateway_url" >> /data/.sentinel
   echo "API_URL=$rest_api_url" >> /data/.sentinel
   echo "DOCKERHUB=$privatehub" >> /data/.sentinel
