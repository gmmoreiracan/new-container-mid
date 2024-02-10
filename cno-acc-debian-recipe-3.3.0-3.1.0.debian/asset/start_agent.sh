#!/bin/bash

trap "/usr/share/servicenow/agent-client-collector/bin/acc stop; exit" SIGTERM

set -e
cd /etc/servicenow/agent-client-collector

echo "Containerized ACC" >> acc-meta.txt

if [ -n "$ACC_MID_API_KEY" ]
then
    sed -i 's/api-key: ""/api-key: "'$ACC_MID_API_KEY'"/g' acc.yml
elif [ -n "$ACC_MID_USER" ] && [ -n "$ACC_MID_PASSWORD" ]
then
    sed -i 's/api-key: /#api-key: /g' acc.yml
    sed -i 's/#user: "admin"/user: "'$ACC_MID_USER'"/g' acc.yml
    sed -i 's/#password: "admin"/password: "'$ACC_MID_PASSWORD'"/g' acc.yml
else
    echo "Was not able to to set credential info for ACC web socket"
fi

if [ -n "$ACC_PLUGIN_VERIFICATION" ] 
then
    sed -i 's/#verify-plugin-signature: true/verify-plugin-signature: '$ACC_PLUGIN_VERIFICATION'/g' acc.yml
fi

if [ -n "$ACC_AUTO_MID_SELECTION" ] 
then
    sed -i 's/enable-auto-mid-selection: true/enable-auto-mid-selection: '$ACC_AUTO_MID_SELECTION'/' acc.yml
fi

# To specify the ACC_MID_URL the value should be wss://<mid_host_ip or mid_fqdn>:<ACC listener port>
# i.e. wss://172.62.0.1:8800
if [ -z $ACC_MID_URL ] 
then 
   export SN_INSTANCE_UPPERCASE=${SN_INSTANCE^^}
   export MID_HOST_VAR=SN_ACC_MID_${SN_INSTANCE_UPPERCASE}_SERVICE_HOST
   export ACC_MID_URL=wss://${!MID_HOST_VAR}:8800
fi

sed -i 's#wss://127.0.0.1:8800'#$ACC_MID_URL'#g' acc.yml

if [ "$ACC_DISABLE_ALLOW_LIST" = "true" ]
then
    sed -i '/allow-list/d' acc.yml
fi

# fix for DEF0223219. Do not start Agent API listener when the agents runs in the daemonset with hostNetwork: true
if [ "${ENABLE_API}" != "ENABLED" ] && [ $(grep -q 'disable-rest-api: true' acc.yml || echo "No") == "No" ]
then 
    echo "disable-rest-api: true" >> acc.yml
fi

echo "log-file-and-stdout: true" >> acc.yml

# Handle if there is no newline at end of acc.yml. No newline affects stop/start of container
sed -i -e '$a\' acc.yml

export PATH=/usr/share/servicenow/agent-client-colllector/bin:/etc/servicenow/agent-client-collector/plugins:/etc/servicenow/agent-client-collector/handlers:$PATH

# We wait here until the MID web server starts so once the agent process starts it will connect immediately
if [ -z $ACC_MID_HEALTH_URL ] 
then
  echo "ACC_MID_HEALTH_URL not defined. Starting agent"
else
  set +e
  while true; do
    echo $(date)": Waiting for MID Web server to start..."
    response_code=`curl -k -s --connect-timeout 5 -o /dev/null -w "%{http_code}" ${ACC_MID_HEALTH_URL}`
    if [[ "$response_code" -ge "200" && "$response_code" -lt "400" ]]; then
      echo $(date)": MID Web server is now alive. Starting agent..."
      break
    fi
    sleep 5
  done
  set -e
fi

/usr/share/servicenow/agent-client-collector/bin/acc start --log-file /var/log/servicenow/agent-client-collector/acc.log
