# pssid-daemon Dockerfile
FROM ubuntu:24.04

# no interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# cache rm is to reduce image size after apt-get
RUN apt-get update && apt-get install -y --no-install-recommends \
        iproute2 \
        iw \
        wpasupplicant \
        dhcpcd5 \
        jq \
        tcpdump \
        rsyslog \
        python3 \
        python3-pip \
        curl \
        ca-certificates \
        git \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# pscheduler
# RUN curl -s https://raw.githubusercontent.com/perfsonar/project/master/install-perfsonar \
#     | sh -s - --auto-updates --tunings testpoint

# ensuring repo is signed for python pscheduler
RUN curl -fsSL https://downloads.perfsonar.net/debian/perfsonar-release.gpg.key \
| gpg --dearmor -o /usr/share/keyrings/perfsonar.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/perfsonar.gpg] https://downloads.perfsonar.net/debian perfsonar-release main" \
> /etc/apt/sources.list.d/perfsonar.list

RUN apt-get update && apt-get install -y python3-pscheduler

# python depenencies
RUN pip3 install croniter jinja2 --break-system-packages

# layer 2 and 3 scripts
RUN git clone https://github.com/UMNET-perfSONAR/VT-collab.git /tmp/VT-collab && \
    mkdir -p /usr/lib/exec/pssid && \
    cp /tmp/VT-collab/pssid-80211 \
       /tmp/VT-collab/pssid-dhcp \
       /tmp/VT-collab/libpssid.sh \
       /usr/lib/exec/pssid/ && \
    chmod +x /usr/lib/exec/pssid/pssid-80211 \
              /usr/lib/exec/pssid/pssid-dhcp && \
    rm -rf /tmp/VT-collab

# daemon script
RUN git clone https://github.com/UMNET-perfSONAR/pssid-daemon.git /tmp/pssid-daemon && \
    mkdir -p /usr/bin/pssid && \
    cp /tmp/pssid-daemon/pssid-daemon.py \
       /tmp/pssid-daemon/batch_processor_format_template.j2 \
       /usr/bin/pssid/ && \
    rm -rf /tmp/pssid-daemon

# default config directory (real config mounted at runtime, see top of file)
RUN mkdir -p /etc/pssid

# syslog
RUN mkdir -p /var/log /var/spool/rsyslog && \
    touch /var/log/pssid.log && \
    cat > /etc/rsyslog.conf <<'EOF'
# rsyslog minimal config for container use

# load modules
module(load="imuxsock" SysSock.Use="on")

# disable kernel messages (no /proc/kmsg in container)
# module(load="imklog")

global(workDirectory="/var/spool/rsyslog")

# write local0 (pssid) to its own log file, flushing after each line
local0.*    /var/log/pssid.log
EOF

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /usr/bin/pssid

# uncomment to use the container log file instead of host
# VOLUME ["/var/log"]

ENTRYPOINT ["/entrypoint.sh"]

# default args
# CMD ["--config", "/etc/pssid/pssid_config.json"]
