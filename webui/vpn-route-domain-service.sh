#!/bin/sh
# vpn-route-domain-service.sh - Handles service events from web UI

source /usr/sbin/helper.sh

TYPE=$1
EVENT=$2

DNSMASQ_CONF="/jffs/configs/dnsmasq.conf.add"
STATUS_FILE="/www/user/vpn-route-domain-status.htm"

# Handle refresh request - read current domains from dnsmasq config
if [ "$EVENT" = "vpnroutedomain" -a "$TYPE" = "refresh" ]; then
    logger -t "vpn-route-domain" "Refreshing domain list from config..."

    IPSET_NAME=$(am_settings_get vpn_rd_ipset)
    [ -z "$IPSET_NAME" ] && IPSET_NAME="vpn_domains"

    # Extract domains from dnsmasq.conf.add
    DOMAINS=$(grep "ipset=.*/$IPSET_NAME" "$DNSMASQ_CONF" 2>/dev/null | \
        sed "s|ipset=/||g; s|/$IPSET_NAME||g" | \
        tr '/' '\n' | \
        grep -v '^$' | \
        grep -v ':' | \
        sort -u)

    # Write to status file for web UI to read
    echo "$DOMAINS" > "$STATUS_FILE"

    logger -t "vpn-route-domain" "Found domains: $(echo $DOMAINS | tr '\n' ' ')"
fi

# Handle apply/restart request
if [ "$EVENT" = "vpnroutedomain" -a "$TYPE" = "restart" ]; then
    logger -t "vpn-route-domain" "Applying settings from web UI..."
    
    # Read settings from custom_settings.txt
    IPSET_NAME=$(am_settings_get vpn_rd_ipset)
    VPN_TABLE=$(am_settings_get vpn_rd_table)
    DOMAINS=$(am_settings_get vpn_rd_domains)
    
    # Use defaults if not set
    [ -z "$IPSET_NAME" ] && IPSET_NAME="vpn_domains"
    [ -z "$VPN_TABLE" ] && VPN_TABLE="wgc1"
    
    if [ -n "$DOMAINS" ]; then
        # Convert newlines to commas
        DOMAIN_LIST=$(echo "$DOMAINS" | tr '\n' ',' | sed 's/,$//')
        
        # Apply using vpn-route-domain.sh
        sh /jffs/scripts/vpn-route-domain.sh \
            --ipset "$IPSET_NAME" \
            --table "$VPN_TABLE" \
            add "$DOMAIN_LIST"
    fi
    
    logger -t "vpn-route-domain" "Settings applied"
fi
