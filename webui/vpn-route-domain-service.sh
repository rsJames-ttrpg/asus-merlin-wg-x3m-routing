#!/bin/sh
# vpn-route-domain-service.sh - Handles service events from web UI

source /usr/sbin/helper.sh

TYPE=$1
EVENT=$2

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
