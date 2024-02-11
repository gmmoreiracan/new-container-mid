# ACC Preparation stage
# In this stage we are preparing the installation file to minimize the layers in the official IMAGE
FROM bitnami/minideb:bullseye-amd64 AS acc_installer

ARG ACC_INSTALLATION_URL=https://install.service-now.com/glide/distribution/builds/package/app-signed/agent-client-collector-3.1.0-debian-9_amd64.deb
ARG ACC_SIGNATURE_URL=https://install.service-now.com/glide/distribution/builds/package/app-signed/agent-client-collector-3.1.0-debian-9_amd64-deb-deb.zip
ARG ACC_INSTALLATION_FILE
ARG ACC_SIGNATURE_VALIDATION=true

WORKDIR /opt/acc_assets/

# Copy the files that can be used later on
# In case of ACC_INSTALLATION_FILE customer should put the file in the asset directory
# Example: ACC_INSTALLATION_FILE=agent-client-collector-3.1.0-debian-9_amd64.deb should include only the file name

COPY asset/* ./

RUN apt-get update && apt-get install -y curl unzip dpkg-sig gnupg

RUN echo "Check ACC installer URL: ${ACC_INSTALLATION_URL} or Local installer: ${ACC_INSTALLATION_FILE}"

# Download the installation ZIP file or using the local one
RUN if [ -z "$ACC_INSTALLATION_FILE" ]; then \
      curl -L $ACC_INSTALLATION_URL -o agent-client-collector.deb ; \
    else \
      echo "Use local file: $ACC_INSTALLATION_FILE" &&  \
      mv $ACC_INSTALLATION_FILE ./agent-client-collector.deb ; \
    fi && \
    if [ -z "$ACC_SIGNATURE_VALIDATION" ] || [ "$ACC_SIGNATURE_VALIDATION" = "true" ]; then \
      curl -L $ACC_SIGNATURE_URL -o agent-client-collector-sig.zip && \
      unzip agent-client-collector-sig.zip && \
      gpg --import ServiceNow_Digicert_Public.gpg && \
      dpkg-sig --verify agent-client-collector.deb ; \
    fi

# ACC Installation Stage
FROM bitnami/minideb:bullseye-amd64

ARG CONTAINER_TYPE=k8s
ARG USER_ID=1001
ARG GROUP_ID=1001

ENV ACC_USER="servicenow" \
    ACC_GROUP="servicenow" \
    ACC_CONF_DIR="/etc/servicenow/agent-client-collector/" \
    ACC_LOG_DIR="/var/log/servicenow/agent-client-collector/" \
    ACC_CACHE_DIR="/var/cache/servicenow/agent-client-collector/" \
    ACC_INSTALL_DIR="/usr/share/servicenow/agent-client-collector/" \
    AGENT_ROOT="/usr/share" \
    AGENT_CACHE_ROOT="/var/cache" \
    AGENT_CONFIG_ROOT="/etc" \
    AGENT_LOG_ROOT="/var/log" \
    AGENT_RUN_ROOT="/var/run" \
    RUBYOPT="-Eutf-8" \
    LANG="en_US.UTF-8"


COPY --from=acc_installer /opt/acc_assets/agent-client-collector.deb /opt/acc_assets/start_agent.sh ./

RUN	apt-get update && apt-get install -y curl procps && \
  dpkg -i agent-client-collector.deb && \
	cp -p /etc/servicenow/agent-client-collector/acc.yml.example /etc/servicenow/agent-client-collector/acc.yml && \
    cp -p /etc/servicenow/agent-client-collector/check-allow-list.json.default /etc/servicenow/agent-client-collector/check-allow-list.json && \
    rm -f /etc/servicenow/agent-client-collector/check-allow-list.json.default /etc/servicenow/agent-client-collector/acc.yml.example && \
	rm -f agent-client-collector.deb && \
    # # Remove embedded data due to the high number of vulnerabilities and due to unused data by CNO
    rm -rf /usr/share/servicenow/agent-client-collector/embedded && \
    # Create directories in advance with placeholders to avoid permission issues
    mkdir -p /var/cache/servicenow/agent-client-collector/ && \
    touch /var/cache/servicenow/agent-client-collector/.placeholder && \
    touch /var/log/servicenow/.placeholder && \
    touch /tmp/.placeholder && \
    touch /var/cache/servicenow/.placeholder && \
    # ============= OpenShift ============================
    if [ "$CONTAINER_TYPE" = "oc" ]; then \
        echo "Building OpenShift container" && \
        usermod -a -G root $ACC_USER && \
        # In OpenShift we don't know the selected User ID and to avoud premission issues we are generating the directories in advance  \
        # for non-root containers
        chmod -R g+rw $ACC_CONF_DIR $ACC_LOG_DIR $ACC_CACHE_DIR && \
        chmod -R g+rwx $ACC_INSTALL_DIR && \
        chown -R $ACC_USER:root $ACC_CONF_DIR $ACC_LOG_DIR $ACC_CACHE_DIR $ACC_INSTALL_DIR /tmp/ && \
        chown $ACC_USER:root /start_agent.sh && \
        chmod g+x /start_agent.sh;\
      else \
        echo "Building K8S container" && \
        usermod -u $USER_ID $ACC_USER && \
        groupmod -g $GROUP_ID $ACC_GROUP && \
        chmod -R +rw $ACC_CONF_DIR $ACC_LOG_DIR $ACC_CACHE_DIR && \
        chown $ACC_USER:$ACC_GROUP /start_agent.sh && \
        chown -R $ACC_USER:$ACC_GROUP $ACC_CONF_DIR $ACC_LOG_DIR $ACC_CACHE_DIR $ACC_INSTALL_DIR /tmp/; \
    fi

RUN apt-get install sudo -y && \
    echo "$ACC_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$ACC_USER && \
    chmod 0440 /etc/sudoers.d/$ACC_USER

USER $ACC_USER;

CMD ["/bin/bash", "/start_agent.sh"]
