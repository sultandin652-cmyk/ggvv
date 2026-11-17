#!/bin/bash

# ============================================
#   Kryptex XMRig Docker/Container Setup
#   No systemd - Screen - Max Hashrate
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
echo "   Kryptex XMRig Max Hashrate Setup"
echo "   Auto CPU/RAM Detect + Max Speed"
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

# Step 3: Auto detect CPU + RAM
TOTAL_CORES=$(nproc)
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
# Max threads RAM ke hisaab se - har thread 2GB leta hai
MAX_BY_RAM=$(echo "$TOTAL_RAM_GB / 2" | bc)
# Jo bhi kam ho woh lo
if [ "$TOTAL_CORES" -le "$MAX_BY_RAM" ]; then
    THREADS=$TOTAL_CORES
else
    THREADS=$MAX_BY_RAM
fi
# HugePages = threads * 200
HUGEPAGES=$(echo "$THREADS * 200" | bc)
[ "$HUGEPAGES" -lt 1280 ] && HUGEPAGES=1280

echo -e "${CYAN}── System Detected ─────────────────────${NC}"
echo -e "  CPU Cores : ${YELLOW}${TOTAL_CORES}${NC}"
echo -e "  RAM       : ${YELLOW}${TOTAL_RAM_GB} GB${NC}"
echo -e "  Threads   : ${YELLOW}${THREADS} (Maximum)${NC}"
echo -e "  HugePages : ${YELLOW}${HUGEPAGES}${NC}"
echo -e "${CYAN}─────────────────────────────────────────${NC}"

# Step 4: Clone + Build XMRig
echo -e "${YELLOW}[3/6] Building XMRig (2-5 min)...${NC}"
cd ~
if [ -d "xmrig" ]; then
    echo "XMRig folder exists, re-using..."
else
    git clone https://github.com/xmrig/xmrig.git > /dev/null 2>&1
fi
cd ~/xmrig
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release > /dev/null 2>&1
make -j$(nproc) > /dev/null 2>&1
echo -e "${GREEN}✓ XMRig built${NC}"

# Step 5: HugePages
echo -e "${YELLOW}[4/6] Setting HugePages = ${HUGEPAGES}...${NC}"
sysctl -w vm.nr_hugepages=$HUGEPAGES > /dev/null 2>&1
grep -q "vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null && \
    sed -i "s/vm.nr_hugepages.*/vm.nr_hugepages=$HUGEPAGES/" /etc/sysctl.conf || \
    echo "vm.nr_hugepages=$HUGEPAGES" >> /etc/sysctl.conf 2>/dev/null
modprobe msr 2>/dev/null
echo -e "${GREEN}✓ HugePages set${NC}"

# Step 6: Config
echo -e "${YELLOW}[5/6] Writing max config...${NC}"
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
        "threads": ${THREADS},
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
echo -e "${GREEN}✓ Config written (${THREADS} threads)${NC}"

# Step 7: Start + Auto restart on fail
echo -e "${YELLOW}[6/6] Starting XMRig...${NC}"

# Simple restart loop script
cat > /usr/local/bin/xmrig-run.sh << 'RUN'
#!/bin/bash
while true; do
    /root/xmrig/build/xmrig -c /root/xmrig/build/config.json
    echo "[$(date)] XMRig crashed/stopped - restarting in 5s..." >> /var/log/xmrig.log
    sleep 5
done
RUN
chmod +x /usr/local/bin/xmrig-run.sh

# Screen mein loop ke saath start karo
screen -dmS mining /usr/local/bin/xmrig-run.sh
sleep 3

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   MINING STARTED! 🚀${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Cores    : ${YELLOW}${TOTAL_CORES}${NC}"
echo -e "  Threads  : ${YELLOW}${THREADS} (Max)${NC}"
echo -e "  RAM      : ${YELLOW}${TOTAL_RAM_GB} GB${NC}"
echo -e "  Pool     : ${YELLOW}${POOL_MAIN}${NC}"
echo -e "  Username : ${YELLOW}${USERNAME}${NC}"
echo ""
echo -e "${CYAN}Commands:${NC}"
echo -e "  Live logs : ${YELLOW}screen -r mining${NC}"
echo -e "  Detach    : ${YELLOW}Ctrl+A phir D${NC}"
echo -e "  Stop      : ${YELLOW}killall xmrig${NC}"
echo -e "  Status    : ${YELLOW}screen -list${NC}"
echo ""
echo -e "${CYAN}Live output (Ctrl+A+D se exit):${NC}"
sleep 2
screen -r mining
