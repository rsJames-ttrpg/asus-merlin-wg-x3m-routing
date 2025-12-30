#!/bin/sh

# Configuration - edit these for your setup
IPSET_NAME="vpn_domains"
VPN_TABLE="wgc1"          # WireGuard uses wgc1, wgc2, etc.
FWMARK="0x1000/0x1000"
PRIORITY="9995"
DNSMASQ_CONF="/jffs/configs/dnsmasq.conf.add"

usage() {
    echo "Usage:"
    echo "  vpn-route-domain.sh add domain1.com,domain2.com"
    echo "  vpn-route-domain.sh remove domain1.com"
    echo "  vpn-route-domain.sh domains          # list routed domains"
    echo "  vpn-route-domain.sh list             # list IPs in ipset"
    echo "  vpn-route-domain.sh fix-routing"
    echo "  vpn-route-domain.sh status"
    exit 1
}

fix_routing() {
    ip rule del fwmark $FWMARK lookup ovpnc1 2>/dev/null
    ip rule del fwmark $FWMARK lookup $VPN_TABLE 2>/dev/null
    ip rule add fwmark $FWMARK lookup $VPN_TABLE priority $PRIORITY
    echo "Routing fixed: fwmark $FWMARK now uses $VPN_TABLE"
}

get_current_domains() {
    grep "ipset=.*/$IPSET_NAME" "$DNSMASQ_CONF" 2>/dev/null | \
        sed "s|ipset=/||g; s|/$IPSET_NAME||g" | \
        tr '/' '\n' | \
        grep -v '^$' | \
        sort -u
}

write_domains() {
    # Remove all existing ipset lines for our ipset
    sed -i "/ipset=.*\/$IPSET_NAME/d" "$DNSMASQ_CONF"
    
    # Build new ipset line from sorted unique domains
    DOMAINS="$1"
    if [ -n "$DOMAINS" ]; then
        IPSET_LINE="ipset=/"
        for d in $DOMAINS; do
            IPSET_LINE="${IPSET_LINE}${d}/"
        done
        IPSET_LINE="${IPSET_LINE}${IPSET_NAME}"
        echo "$IPSET_LINE" >> "$DNSMASQ_CONF"
    fi
}

ensure_ipset_exists() {
    if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        ipset create "$IPSET_NAME" hash:net family inet hashsize 1024 maxelem 65536
        echo "Created ipset $IPSET_NAME"
    fi
    
    # Ensure iptables rule exists
    if ! iptables -t mangle -C PREROUTING -i br0 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 0x1000/0x1000 2>/dev/null; then
        iptables -t mangle -A PREROUTING -i br0 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 0x1000/0x1000
        echo "Created iptables marking rule"
    fi
}

add_domains() {
    NEW_DOMAINS=$(echo "$1" | tr ',' '\n')
    CURRENT=$(get_current_domains)
    
    # Merge and dedupe
    ALL_DOMAINS=$(printf "%s\n%s" "$CURRENT" "$NEW_DOMAINS" | grep -v '^$' | sort -u)
    
    write_domains "$ALL_DOMAINS"
    ensure_ipset_exists
    fix_routing
    
    echo "Restarting dnsmasq..."
    service restart_dnsmasq
    
    echo ""
    echo "Current domains routed through VPN:"
    get_current_domains
}

remove_domain() {
    DOMAIN="$1"
    CURRENT=$(get_current_domains)
    
    if echo "$CURRENT" | grep -q "^${DOMAIN}$"; then
        # Filter out the domain
        NEW_DOMAINS=$(echo "$CURRENT" | grep -v "^${DOMAIN}$")
        write_domains "$NEW_DOMAINS"
        
        echo "Removed $DOMAIN from VPN routing"
        echo "Restarting dnsmasq..."
        service restart_dnsmasq
        echo ""
        echo "Note: Existing IPs for $DOMAIN remain in ipset until reboot."
    else
        echo "Domain $DOMAIN not found in VPN routing config"
    fi
}

list_domains() {
    echo "=== Domains routed through VPN ==="
    DOMAINS=$(get_current_domains)
    if [ -n "$DOMAINS" ]; then
        echo "$DOMAINS"
    else
        echo "No domains configured"
    fi
}

status() {
    echo "=== IP Rules (VPN related) ==="
    ip rule show | grep -E "(wgc|ovpnc|$FWMARK)"
    echo ""
    echo "=== Routed Domains ==="
    get_current_domains || echo "None"
    echo ""
    echo "=== IPSET $IPSET_NAME ==="
    ENTRIES=$(ipset list $IPSET_NAME 2>/dev/null | grep "Number of entries" | awk '{print $4}')
    echo "Entries: ${ENTRIES:-0}"
    echo ""
    echo "=== WireGuard Status ==="
    wg show 2>/dev/null | head -5 || echo "WireGuard not running"
}

case "$1" in
    add)
        [ -z "$2" ] && usage
        echo "Adding domains: $2"
        add_domains "$2"
        ;;
    remove)
        [ -z "$2" ] && usage
        remove_domain "$2"
        ;;
    domains)
        list_domains
        ;;
    list)
        ipset list "$IPSET_NAME" 2>/dev/null || echo "IPSET $IPSET_NAME not found"
        ;;
    fix-routing)
        fix_routing
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac
