#!/bin/bash
BASEDIR=`pwd`

prepareforUpdate() {
    user=$(cat /etc/passwd | egrep -e ansible | awk -F ":" '{ print $1}')
    if [[ $user != "cybercns" ]]; then
        useradd --no-create-home cybercns | true
    fi
    # Creating temporary cybercns home directory for matlab cache data
    if [ ! -d /home/cybercns/.config/ ]; then
        mkdir -p /home/cybercns/.config
    fi
    chown -R cybercns. /home/cybercns/
    d=`cat /sys/class/dmi/id/product_uuid`
    echo $d > /opt/.sysproductId
    chown -R cybercns. /opt/.sysproductId
    # rm /tmp/matplotlib-* | true
    cd $BASEDIR
    dpkg --configure -a
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive  apt install -y libpython3.9 wkhtmltopdf xvfb
    # Installing pandoc
    pandoc_status=`dpkg -l | grep pandoc`
    if [ $? -ne 0 ]; then
        wget https://netalyticsvulnerabilitydownload.s3-ap-southeast-1.amazonaws.com/pandoc-2.11.4-1-amd64.deb -O /tmp/pandoc-2.11.4-1-amd64.deb
        if [ -f /tmp/pandoc-2.11.4-1-amd64.deb ]; then
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/pandoc-2.11.4-1-amd64.deb
            apt -f install -y
            rm -rf /tmp/pandoc-2.11.4-1-amd64.deb
        else
           echo "Error in downloading pandoc"
        fi
    fi
    /opt/cybercns/cyberenv/bin/python -m pip install -r requirements.txt
    /opt/cybercns/cyberenv/bin/python -m pip install -r opt/cybercns/integrations/requirements.txt
    if [ ! -d /usr/share/nginx/cybercns/ui ]; then
        mkdir /usr/share/nginx/cybercns/ui
    fi
    if [ ! -d /var/log/cybercnslogs/ ]; then
      mkdir -p /var/log/cybercnslogs/
    fi
    if [ ! -d /opt/ReportTpl/ ]; then
      mkdir -p /opt/ReportTpl/
    fi
    if [ ! -d /opt/agents/ReportTpl/ ]; then
      ln -s /opt/ReportTpl /opt/agents/ReportTpl
    fi
    if [ ! -d /opt/custom_reports/ ]; then
      mkdir -p /opt/custom_reports
    fi
    if [ ! -d /opt/AdData ]; then
      mkdir -p /opt/AdData
    fi
    if [ ! -d /opt/temp ]; then
      mkdir -p /opt/temp
    fi
    if [ ! -d /opt/firewallData ]; then
      mkdir /opt/firewallData
    fi
    if [ ! -d /opt/custom_reports/standard_reports ]; then
      mkdir -p /opt/custom_reports/standard_reports
    fi
    chown -R cybercns. /usr/share/nginx/cybercns/ui /var/log/cybercnslogs /opt/ReportTpl /opt/custom_reports /opt/AdData /opt/firewallData /opt/custom_reports/standard_reports /opt/temp
}

updateCode() {
    cd $BASEDIR
    if [ ! -d /opt/ ]; then
        mkdir /opt
    fi
    if [ ! -d /opt/scripts ]; then
        mkdir -p /opt/scripts/
    fi
    if [ ! -d /opt/indexpattern ]; then
        mkdir -p /opt/indexpattern
    fi
    rsync -aS framework/ /opt/framework --delete
    chown -R cybercns. /opt/framework
    cd $BASEDIR/opt
    rsync -aSP $BASEDIR/opt/ReportTpl/ /opt/ReportTpl/ --delete
    rsync -aSP $BASEDIR/opt/agents/ /opt/agents/ --delete --exclude runtimereports --exclude assessments
    rsync -aSP $BASEDIR/opt/dashboards/ /opt/dashboards/ --delete
    rsync -aSP $BASEDIR/opt/osDefinitions/ /opt/osDefinitions/ --delete
    rsync -aSP $BASEDIR/opt/ReportTemplates/ /opt/ReportTemplates/ --delete
    rsync -aSP $BASEDIR/opt/cybercns/cyberbase/ /opt/cybercns/cyberbase/ --delete --exclude .env --exclude meta
    rsync -aSP $BASEDIR/opt/cybercns/scheduler/ /opt/cybercns/scheduler/ --delete --exclude .env
    rsync -aSP $BASEDIR/opt/cybercns/integrations/ /opt/cybercns/integrations/ --delete --exclude .env
    rsync -aSP $BASEDIR/scripts/ /opt/scripts/ --delete
    rsync -aSP $BASEDIR/opt/indexpattern/ /opt/indexpattern/ --delete
    rsync -asP $BASEDIR/opt/cybercns_nginx_template.conf /opt/cybercns_nginx_template.conf

    # Upgrading manuf data
    cd /opt/cybercns/cyberbase/
    /opt/cybercns/cyberenv/bin/python manuf.py -u
    cd $BASEDIR

    if [ ! -d /opt/agents/runtimereports ]; then
         mkdir -p /opt/agents/runtimereports
    fi
    if [ ! -d /opt/cybertemp ]; then
         mkdir -p /opt/cybertemp
    fi
    if [ ! -d /opt/CyberCNSAgentV2/netatemp ]; then
         mkdir -p /opt/CyberCNSAgentV2/netatemp;chown -R cybercns. /opt/CyberCNSAgentV2/netatemp
    fi
    if [ ! -d /opt/AdData ]; then
      mkdir -p /opt/AdData
    fi
    if [ ! -f /opt/cybercns/scheduler/.env ]; then
       ln -s /opt/cybercns/cyberbase/.env /opt/cybercns/scheduler/.env
    fi
    chown -R cybercns. /opt/agents/runtimereports /opt/cybertemp /opt/agents/ /opt/externalscanresults \
    /opt/dashboards/ /opt/osDefinitions/ /opt/ReportTemplates/ /opt/cybercns/cyberbase/ /opt/cybercns/integrations/ /opt/ReportTpl/ /opt/AdData /opt/scripts /opt/indexpattern
    cd $BASEDIR
    rsync -aS etc/systemd/system/* /etc/systemd/system/ --exclude keycloak.service
    systemctl daemon-reload
}

configureframework() {
    cd /opt/framework
    /opt/cybercns/cyberenv/bin/python -m pip install -e .
}

configureSecurity() {
    cd /opt/cybercns/cyberbase
    /opt/cybercns/cyberenv/bin/python $BASEDIR/scripts/updateRoles.py updatepolicy
    /opt/cybercns/cyberenv/bin/python $BASEDIR/scripts/updateRoles.py upgraderedis
}

# todo:- need to get realm name for configuring kibana dashboards
#updateKibanaDashboards() {
#    cd /opt/cybercns/cyberbase
#    /opt/cybercns/cyberenv/bin/python -c "from keyCloakManager import *;import asyncio;asyncio.run(KeyClockSecret().createKibanaDashboards())"
#}

updateBuildInfo() {
    cd $BASEDIR
    /opt/cybercns/cyberenv/bin/python scripts/updateBuildInfo.py backend
}

restartServices() {
    systemctl enable redis-server
    systemctl enable elasticsearch
    systemctl enable kibana
    systemctl enable keycloak
    systemctl start redis-server
    systemctl start elasticsearch
    systemctl start kibana
    systemctl start keycloak
    systemctl enable framework
    systemctl enable framework@{8001..8004}.service
    systemctl enable integrations
    systemctl enable integrations@{9003..9006}.service
    systemctl enable cyberalertprocessor
    systemctl enable cyberprevilaged
    systemctl enable cyberscheduler.service
    systemctl disable cyberassetprocessor@{6..10}.service
    systemctl enable cyberassetprocessor@{1..5}.service
    systemctl enable cyberwebhookprocessor
    systemctl stop framework
    systemctl stop framework@{8001..8004}.service | true
    systemctl start framework
    systemctl start framework@{8001..8004}.service | true
    systemctl stop integrations
    systemctl stop integrations@{9003..9006}.service | true
    systemctl start integrations
    systemctl start integrations@{9003..9006}.service | true
    systemctl stop cyberalertprocessor
    systemctl start cyberalertprocessor
    systemctl stop cyberprevilaged
    systemctl start cyberprevilaged
    systemctl stop cyberscheduler.service
    systemctl start cyberscheduler.service
    systemctl stop cyberassetprocessor@{1..10}.service
    systemctl start cyberassetprocessor@{1..5}.service
    systemctl stop cyberwebhookprocessor
    systemctl start cyberwebhookprocessor
}

updateDefaultRoles() {
    cd /opt/cybercns/cyberbase
    FILE=/opt/cybercns/cyberbase/kibana-reports-fix.sh
    if [ -f "$FILE" ]; then
        echo "$FILE exists."
        sh $FILE
    else
        echo "$FILE does not exist.So we are not installing kibana reports plugin issue shell script;"
    fi
    /opt/cybercns/cyberenv/bin/python $BASEDIR/scripts/updateRoles.py
}




enableNotificationRules() {
    cd /opt/cybercns/cyberbase/
    /opt/cybercns/cyberenv/bin/python /opt/cybercns/cyberbase/enable_notification.py
}


remediationBaselineRemoval() {
    cd /opt/cybercns/cyberbase/
    /opt/cybercns/cyberenv/bin/python /opt/cybercns/cyberbase/remediationBaselineRemoval.py
}



configureDefaultCron() {
   touch /var/log/jobCleaner.log /var/log/jobLogCleaner.log /var/log/cybercnslogs/scoreevaluator.log /var/log/cleanupScript.log /var/log/appbaselineprocessor.log /var/log/remediationprocessor.log /var/log/azureadevent.log /var/log/adauditticket.log /var/log/cyberschedule_runner.log /var/log/cybercnslogs/reportprocessor.log /var/log/suppressionprocessor.log /var/log/cybercnslogs/assetdataprocessor.log /var/log/cybercns_assessment.log /var/log/cybercns/azureadEvents_generator.log /var/log/agentNotificationProcessor.log
   chown -R cybercns. /var/log/jobCleaner.log /var/log/jobLogCleaner.log /var/log/cybercnslogs/scoreevaluator.log /var/log/cleanupScript.log /var/log/appbaselineprocessor.log /var/log/remediationprocessor.log /var/log/azureadevent.log /var/log/adauditticket.log /var/log/cyberschedule_runner.log /var/log/cybercnslogs/reportprocessor.log /var/log/suppressionprocessor.log /var/log/cybercnslogs/assetdataprocessor.log /var/log/cybercns_assessment.log /var/log/cybercns/azureadEvents_generator.log /var/log/agentNotificationProcessor.log
   cronstring="10 */3 * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python ScoreEvaluator.py >> /var/log/cybercnslogs/scoreevaluator.log 2>&1"
   echo "$cronstring" > /etc/cron.d/cyberscoreevaluator
   # running every 15 minutes _validateNetworkInterface method
   cronstring="*/15 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py validateNetworkInterface >> /var/log/networkinterfacevalidation.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   cronstring="*/10 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py >> /var/log/jobLogCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Cleaning assets every day at 1:20 am UTC
   cronstring="20 1 * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py cleanupassets >> /var/log/jobCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Updating jobs from redis every 15
   cronstring="*/15 * * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py jobupdater >> /var/log/jobCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Cleaning log files for every 30 minutes
   cronstring="*/30 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py logcleaner >> /var/log/jobLogCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Cleaning temp files for every 5 minutes
   cronstring="*/5 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py cleanuptempfile >> /var/log/jobLogCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Validating service status for every 5 minutes
   cronstring="*/5 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py servicemonitor >> /var/log/jobLogCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Validating tomany open file errors for every 5 minutes
   cronstring="*/5 * * * * root cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python jobCleaner.py tomanyopenfiles >> /var/log/jobLogCleaner.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Running Database cleaner service status for every 3 hours
   cronstring="5 */3 * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python cleanupScript.py >> /var/log/cleanupScript.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # updating remediation lapsed by snoozedays at minute 20 past every 6th hour
   cronstring="20 */6 * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python SuppressionProcessor.py >> /var/log/suppressionprocessor.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # Backing up postgressDB once per every 6 hours
   cronstring="5 */6 * * * root chmod +x /opt/scripts/postgressBackup.sh;/opt/scripts/postgressBackup.sh"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   cronstring="5 */6 * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python AppBaseLineProcessor.py >> /var/log/appbaselineprocessor.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   cronstring="*/30 * * * * root chmod +x /opt/cybercns/cyberbase/remediation-processor.sh;/opt/cybercns/cyberbase/remediation-processor.sh >> /var/log/remediationprocessor.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
    # cronstring="*/30 * * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python azureadEvents_generator.py >> /var/log/azureadevent.log 2>&1"
   cronstring="*/30 * * * * root systemctl start azure_events_generator.service"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   # cronstring="*/15 * * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python Adauditprocessor.py >> /var/log/adauditticket.log 2>&1"
   # echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   cronstring="*/15 * * * * cybercns cd /opt/cybercns/cyberbase/;/opt/cybercns/cyberenv/bin/python agentNotificationProcessor.py >> /var/log/agentNotificationProcessor.log 2>&1"
   echo "$cronstring" >> /etc/cron.d/cyberscoreevaluator
   cronstring="10 */6 * * * root cd /opt/cybercns/cyberbase/;chmod +x restartServices.sh;./restartServices.sh"
   echo "$cronstring" > /etc/cron.d/restartservices
   cronstring="*/30 * * * * root systemctl start salt-minion"
   echo "$cronstring" >> /etc/cron.d/restartservices
   cronstring="13,27,43,57 * * * * root sync;echo 3 > /proc/sys/vm/drop_caches"
   echo "$cronstring" >> /etc/cron.d/restartservices
   chmod +x /etc/cron.d/restartservices
   chmod +x /etc/cron.d/cyberscoreevaluator
}

updateSqlSchema() {
    sed -i "/Forgot\ Password/c\doForgotPassword=Forgot\ Password\ \/\ Reset\ MFA" /opt/keycloak/themes/base/login/messages/messages_en.properties
    sed -i 's/termsTitle=.*/termsTitle=Terms Of Use/' messages_en.properties /opt/keycloak/themes/base/login/messages/messages_en.properties
sed -i 's/termsText=.*/termsText=<p>By clicking on the Accept button, you agree to the CyberCNS <a target="_blank" href="https:\/\/www.cybercns.com\/terms">Terms of Use<\/a><\/p/>' /opt/keycloak/themes/base/login/messages/messages_en.properties
sed -i 's/termsPlainText=.*/termsPlainText=By clicking on the Accept button, you agree to the CyberCNS Terms of Use https:\/\/wwww.cybercns.com\/\terms/' /opt/keycloak/themes/base/login/messages/messages_en.properties
    su - postgres -c "psql -d keycloak -c \"ALTER TABLE user_attribute ALTER COLUMN value TYPE TEXT;\""
}

updateConstraints() {
     cd /opt/cybercns/cyberbase
    /opt/cybercns/cyberenv/bin/python /opt/scripts/updateConstraints.py
}

updateNginx() {
    cd $BASEDIR/scripts
    if [ -L /etc/nginx/sites-enabled/default ]; then
       /usr/bin/unlink /etc/nginx/sites-enabled/default
    fi

    if [ -f /etc/nginx/sites-available/default ]; then
       rm /etc/nginx/sites-available/default
    fi

    if [ -f /etc/nginx/conf.d/default.conf ]; then
       rm /etc/nginx/conf.d/default.conf
    fi

    for entry in "/etc/nginx/conf.d"/*
    do
      echo "$entry"
      sed -i "/proxy_set_header  Authorization/d" $entry
      sed -i 's/127.0.0.1:9000/backend/g' $entry
      sed -i 's/127.0.0.1:9002/integrations/g' $entry
    done
    # todo:- need to check if line not exists
    FOUND=`fgrep -c "proxy_buffer_size" /etc/nginx/nginx.conf`
    if [ $FOUND -eq 0 ]; then
        awk '/default_type application/{print $0 RS "\tproxy_buffer_size   128k;" RS "\tproxy_buffers   4 256k;" RS "\tproxy_busy_buffers_size   256k;";next}1' /etc/nginx/nginx.conf > /tmp/nginx_test.conf
        mv /tmp/nginx_test.conf /etc/nginx/nginx.conf
    fi
    systemctl stop nginx
    pkill -9 nginx
    rsync -aSP $BASEDIR/etc/nginx/conf.d/upstream.conf /etc/nginx/conf.d/upstream.conf
    # /opt/cybercns/cyberenv/bin/python nginxConfig.py
    systemctl start nginx
}

# updating oval repository
updateOvalRepo() {
    cd $BASEDIR/scripts
    /opt/cybercns/cyberenv/bin/python updateovalRepo.py
    cd $BASEDIR
}

# Enabling on disk swap memory
enableSwap() {
    if [ -z "$(swapon --show)" ]; then
       avilableDisk=`df  / | awk 'NR==2 {print $4}'`
       if [ $avilableDisk -gt 26214400 ]; then
           echo "Creating Swap Memory"
           fallocate -l 16G /swapfile
           chmod 600 /swapfile
           mkswap /swapfile
           swapon /swapfile
           FOUND=`fgrep -c "/swapfile" /etc/fstab`
           if [ $FOUND -eq 0 ]; then
              echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
           fi
       else
          echo "Root Disk Size is less to enable swap"
       fi
    else
       echo "Swap Enabled"
    fi
}

createSymbolicLink() {
	folder=`cat /opt/agents/light_agentVersion.txt| xargs`
	ln -sf /opt/agents/$folder /opt/agents/ccnsagent
}



prepareforUpdate
updateCode
# updateOvalRepo
configureframework
configureSecurity
restartServices
updateConstraints
createSymbolicLink
updateDefaultRoles
updateBuildInfo
configureDefaultCron
updateSqlSchema
updateNginx
enableSwap
enableNotificationRules
remediationBaselineRemoval
