# vpn-route-domain

A simple wrapper script for domain-based VPN routing on Asuswrt-Merlin routers using WireGuard.

## Problem

[x3mRouting](https://github.com/Xentrk/x3mRouting) is excellent for selective VPN routing but was designed for OpenVPN. It hardcodes routing tables to `ovpnc1`, `ovpnc2`, etc., while WireGuard uses `wgc1`, `wgc2`, etc.

This script provides a simple interface for domain-based routing through WireGuard VPN, handling the table name mismatch automatically.

## How It Works

1. Adds domains to dnsmasq's ipset feature (`/jffs/configs/dnsmasq.conf.add`)
2. When clients resolve these domains, IPs are automatically added to an ipset
3. iptables marks traffic destined for IPs in the ipset
4. Policy routing sends marked traffic through the WireGuard tunnel
```
LAN Clients → DNS (Pi-hole/dnsmasq) → Router populates ipset
                                            ↓
                                      Traffic to IPs in ipset
                                            ↓
                                      Marked with fwmark
                                            ↓
                                      Routed through WireGuard VPN
```

## Requirements

- Asuswrt-Merlin firmware
- WireGuard VPN client configured (WGC1)
- Entware installed
- x3mRouting installed (for initial ipset/iptables setup, optional for ongoing use)

## Installation

### Option 1: CLI Only (Quick Setup)

SSH into your router and run:
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vpn-route-domain/main/vpn-route-domain.sh -o /jffs/scripts/vpn-route-domain.sh
chmod +x /jffs/scripts/vpn-route-domain.sh

# Add to startup for persistence
cat >> /jffs/scripts/services-start << 'EOF'
#!/bin/sh
sleep 10 && sh /jffs/scripts/vpn-route-domain.sh fix-routing
EOF
chmod +x /jffs/scripts/services-start

# (Optional) Create symlink for easier access
ln -sf /jffs/scripts/vpn-route-domain.sh /opt/bin/vpn-route-domain
```

### Option 2: Web UI Installation (Recommended)

SSH into your router and run:
```bash
curl -fsSL https://raw.githubusercontent.com/rsJames-ttrpg/vpn-route-domain/main/webui/install-webui.sh | sh
```

This will:
- Install the CLI script
- Add a "VPN Domains" tab to the VPN section of your router's web UI
- Configure automatic startup

After installation, access **VPN → VPN Domains** in your router's web interface.

### Uninstall
```bash
# Remove web UI
rm -rf /jffs/addons/vpn-route-domain
rm /jffs/scripts/vpn-route-domain.sh

# Remove from services-start (edit manually)
nano /jffs/scripts/services-start
# Remove lines between ### vpn-route-domain start ### and ### vpn-route-domain end ###

# Remove from service-event (edit manually)  
nano /jffs/scripts/service-event
# Remove lines between ### vpn-route-domain start ### and ### vpn-route-domain end ###

# Reboot to unmount web UI page
reboot
```


## Usage
```bash
# Add domains to route through VPN
vpn-route-domain.sh add netflix.com,nflxvideo.net

# Remove a domain
vpn-route-domain.sh remove netflix.com

# List domains being routed
vpn-route-domain.sh domains

# List IPs currently in the ipset
vpn-route-domain.sh list

# Show full status
vpn-route-domain.sh status

# Fix routing table (run after reboot or VPN restart)
vpn-route-domain.sh fix-routing
```

## Configuration

Edit the script to change these defaults:
```bash
IPSET_NAME="vpn_domains"    # Name of the ipset
VPN_TABLE="wgc1"            # WireGuard routing table (wgc1-wgc5)
FWMARK="0x1000/0x1000"      # Firewall mark for routing
PRIORITY="9995"             # Routing rule priority
```

## Example: Route Wikipedia and Anna's Archive through VPN
```bash
vpn-route-domain.sh add wikipedia.org,wikimedia.org,wikidata.org,annas-archive.li,annas-archive.se,annas-archive.org
```

## Verifying It Works
```bash
# Check ipset is populated (after DNS lookups occur)
ipset list vpn_domains

# Check routing rule exists
ip rule show | grep wgc1

# Check iptables marking rule
iptables -t mangle -L PREROUTING -v | grep vpn_domains

# Test from a LAN client
traceroute wikipedia.org
# First hop should be VPN gateway (e.g., 10.2.0.1 for Proton VPN)
```

## DNS Setup Notes

For the ipset to populate, DNS queries must pass through the router's dnsmasq. If you use Pi-hole:

**Option A**: Pi-hole forwards to router (recommended)
- Set Pi-hole's upstream DNS to your router's IP
- Router's dnsmasq sees all queries and populates ipset

**Option B**: Conditional forwarding
- Configure Pi-hole to forward specific domains to the router

## Troubleshooting

### Domains not routing through VPN

1. Check ipset has IPs: `ipset list vpn_domains`
2. If empty, DNS queries aren't hitting router's dnsmasq
3. Trigger a lookup: `nslookup wikipedia.org 192.168.50.1` (router IP)

### Routing stops after reboot

Ensure `/jffs/scripts/services-start` contains:
```bash
sleep 10 && sh /jffs/scripts/vpn-route-domain.sh fix-routing
```

### Wrong VPN table

Check your WireGuard client number and update `VPN_TABLE` in the script:
- WGC1 → `wgc1`
- WGC2 → `wgc2`
- etc.

## Credits

- [x3mRouting](https://github.com/Xentrk/x3mRouting) by Xentrk - inspiration and initial ipset/iptables setup
- [Asuswrt-Merlin](https://www.asuswrt-merlin.net/) by RMerlin

## License

MIT License
