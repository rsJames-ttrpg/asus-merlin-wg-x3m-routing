#!/bin/sh

# Defaults
IPSET_NAME="vpn_domains"
VPN_TABLE="wgc1"
FWMARK="0x1000/0x1000"
PRIORITY="9995"
DNSMASQ_CONF="/jffs/configs/dnsmasq.conf.add"

usage() {
    echo "Usage: vpn-route-domain.sh [OPTIONS] COMMAND [ARGS]"
    echo ""
    echo "Commands:"
    echo "  add DOMAIN[,DOMAIN...]    Add domains to VPN routing"
    echo "  remove DOMAIN             Remove domain from VPN routing"
    echo "  domains                   List routed domains"
    echo "  list                      List IPs in ipset"
    echo "  fix-routing               Fix routing table for WireGuard"
    echo "  status                    Show full status"
    echo ""
    echo "Options:"
    echo "  -i, --ipset NAME          IPSET name (default: $IPSET_NAME)"
    echo "  -t, --table TABLE         Routing table (default: $VPN_TABLE)"
    echo "  -m, --fwmark MARK         Firewall mark (default: $FWMARK)"
    echo "  -p, --priority PRIORITY   Rule priority (default: $PRIORITY)"
    echo "  -c, --config PATH         dnsmasq config path (default: $DNSMASQ_CONF)"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  vpn-route-domain.sh add netflix.com,nflxvideo.net"
    echo "  vpn-route-domain.sh --table wgc2 add example.com"
    echo "  vpn-route-domain.sh remove netflix.com"
    exit 0
}

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--ipset)
            IPSET_NAME="$2"
            shift 2
            ;;
        -t|--table)
            VPN_TABLE="$2"
            shift 2
            ;;
        -m|--fwmark)
            FWMARK="$2"
            shift 2
            ;;
        -p|--priority)
            PRIORITY="$2"
            shift 2
            ;;
        -c|--config)
            DNSMASQ_CONF="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

COMMAND="$1"
ARG="$2"

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
    sed -i "/ipset=.*\/$IPSET_NAME/d" "$DNSMASQ_CONF"
    
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
    
    if ! iptables -t mangle -C PREROUTING -i br0 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark $FWMARK 2>/dev/null; then
        iptables -t mangle -A PREROUTING -i br0 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark $FWMARK
        echo "Created iptables marking rule"
    fi
}

add_domains() {
    NEW_DOMAINS=$(echo "$1" | tr ',' '\n')
    CURRENT=$(get_current_domains)
    
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
    echo "=== Domains routed through VPN ($IPSET_NAME) ==="
    DOMAINS=$(get_current_domains)
    if [ -n "$DOMAINS" ]; then
        echo "$DOMAINS"
    else
        echo "No domains configured"
    fi
}

status() {
    echo "=== Configuration ==="
    echo "IPSET:    $IPSET_NAME"
    echo "Table:    $VPN_TABLE"
    echo "Fwmark:   $FWMARK"
    echo "Priority: $PRIORITY"
    echo ""
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

case "$COMMAND" in
    add)
        [ -z "$ARG" ] && usage
        echo "Adding domains: $ARG"
        add_domains "$ARG"
        ;;
    remove)
        [ -z "$ARG" ] && usage
        remove_domain "$ARG"
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
