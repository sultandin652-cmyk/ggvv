#!/bin/bash

# ============================================
#   Kryptex XMRig Docker/Container Setup
#   No systemd - Screen based - Auto restart
# ============================================

POOL_MAIN="xmr-us.kryptex.network:7029"
POOL_GLOBAL="xmr.kryptex.network:7029"
POOL_EU="xmr-eu.kryptex.network:7029"
USERNAME="krxY4NV9DJ.workerZ"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "============================================"
echo "   Kryptex XMRig Docker/Container Setup"
echo "   No systemd + Screen + Auto Restart"
echo "============================================"
echo -e "${NC}"

# Step 1: Kill old xmrig
echo -e "${YELLOW}[1/6] Stopping old xmrig...${NC}"
killall xmrig 2>/dev/null
screen -S mining -X quit 2>/dev/null
sleep 2
echo -e "${GREEN}✓ Cleared${NC}"

# Step 2: Dependencies
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
apt update -qq
apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev screen > /dev/null 2>&1
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 3: Clone + Build XMRig
echo -e "${YELLOW}[3/6] Building XMRig (2-5 min)...${NC}"
cd ~
if [ -d "xmrig" ]; then
    echo "XMRig folder exists, re-using..."
else
    git clone https://github.com/xmrig/xmrig.git > /dev/null 2>&1
fi
cd ~/xmrig
mkdir -p build && cd build
cmake .. > /dev/null 2>&1
make -j$(nproc) > /dev/null 2>&1
echo -e "${GREEN}✓ XMRig built${NC}"

# Step 4: HugePages
echo -e "${YELLOW}[4/6] Setting HugePages...${NC}"
sysctl -w vm.nr_hugepages=3072 > /dev/null 2>&1
grep -q "vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null && \
    sed -i 's/vm.nr_hugepages.*/vm.nr_hugepages=3072/' /etc/sysctl.conf || \
    echo "vm.nr_hugepages=3072" >> /etc/sysctl.conf 2>/dev/null
echo -e "${GREEN}✓ HugePages set${NC}"

# Step 5: Config
echo -e "${YELLOW}[5/6] Writing config...${NC}"
cat > ~/xmrig/build/config.json << EOF
{
    "autosave": true,
    "donate-level": 1,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "fast",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": true,
        "hw-aes": null,
        "priority": 5,
        "asm": true,
        "threads": 12,
        "memory-pool": true,
        "yield": false
    },
    "pools": [
        {
            "url": "${POOL_MAIN}",
            "user": "${USERNAME}",
            "pass": "x",
            "keepalive": true,
            "tls": false
        },
        {
            "url": "${POOL_GLOBAL}",
            "user": "${USERNAME}",
            "pass": "x",
            "keepalive": true,
            "tls": false
        },
        {
            "url": "${POOL_EU}",
            "user": "${USERNAME}",
            "pass": "x",
            "keepalive": true,
            "tls": false
        }
    ]
}
EOF
echo -e "${GREEN}✓ Config written${NC}"

# Step 6: Watchdog script + crontab
echo -e "${YELLOW}[6/6] Setting up watchdog + auto restart...${NC}"

# Watchdog script
cat > /usr/local/bin/xmrig-watch.sh << 'WATCH'
#!/bin/bash
if ! screen -list | grep -q "mining"; then
    sysctl -w vm.nr_hugepages=3072 > /dev/null 2>&1
    screen -dmS mining /root/xmrig/build/xmrig -c /root/xmrig/build/config.json
    echo "[$(date)] XMRig restarted" >> /var/log/xmrig.log
fi
WATCH
chmod +x /usr/local/bin/xmrig-watch.sh

# Crontab setup
(crontab -l 2>/dev/null | grep -v xmrig
echo "*/5 * * * * /usr/local/bin/xmrig-watch.sh"
echo "0 1 * * * killall xmrig 2>/dev/null; sleep 5; sysctl -w vm.nr_hugepages=3072; screen -dmS mining /root/xmrig/build/xmrig -c /root/xmrig/build/config.json") | crontab -

echo -e "${GREEN}✓ Watchdog every 5min + 1AM restart set${NC}"

# Start mining
screen -dmS mining ~/xmrig/build/xmrig -c ~/xmrig/build/config.json
sleep 3

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   MINING STARTED! Expected: 5500+ H/s 🚀${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Pool     : ${YELLOW}${POOL_MAIN}${NC}"
echo -e "  Username : ${YELLOW}${USERNAME}${NC}"
echo -e "  Threads  : ${YELLOW}12${NC}"
echo -e "  Watchdog : ${YELLOW}Har 5 min${NC}"
echo -e "  Restart  : ${YELLOW}Raat 1 AM${NC}"
echo ""
echo -e "${CYAN}Useful Commands:${NC}"
echo -e "  Live logs : ${YELLOW}screen -r mining${NC}"
echo -e "  Detach    : ${YELLOW}Ctrl+A phir D${NC}"
echo -e "  Stop      : ${YELLOW}killall xmrig${NC}"
echo -e "  Status    : ${YELLOW}screen -list${NC}"
echo -e "  Speed log : ${YELLOW}tail -f /var/log/xmrig.log${NC}"
echo ""
echo -e "${CYAN}Live output (Ctrl+A+D se exit):${NC}"
sleep 2
screen -r mining
