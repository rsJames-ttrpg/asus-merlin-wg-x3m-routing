#!/bin/sh
# install-webui.sh - Installs VPN Route Domain web UI

ADDON_DIR="/jffs/addons/vpn-route-domain"
SCRIPT_DIR="/jffs/scripts"

# Check for Addons API support
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]; then
    echo "This firmware does not support addons!"
    exit 1
fi

# Create addon directory
mkdir -p "$ADDON_DIR"

# Download files
echo "Downloading vpn-route-domain..."
curl -fsSL "https://raw.githubusercontent.com/rsJames-ttrpg/vpn-route-domain/main/vpn-route-domain.sh" -o "$SCRIPT_DIR/vpn-route-domain.sh"
curl -fsSL "https://raw.githubusercontent.com/rsJames-ttrpg/vpn-route-domain/main/webui/vpn-route-domain.asp" -o "$ADDON_DIR/vpn-route-domain.asp"
curl -fsSL "https://raw.githubusercontent.com/rsJames-ttrpg/vpn-route-domain/main/webui/vpn-route-domain-service.sh" -o "$ADDON_DIR/vpn-route-domain-service.sh"

chmod +x "$SCRIPT_DIR/vpn-route-domain.sh"
chmod +x "$ADDON_DIR/vpn-route-domain-service.sh"

# Source helper functions
source /usr/sbin/helper.sh

# Get available web UI page slot
am_get_webui_page "$ADDON_DIR/vpn-route-domain.asp"

if [ "$am_webui_page" = "none" ]; then
    echo "Unable to install web page - no slots available"
    exit 1
fi

echo "Mounting web page as $am_webui_page"

# Copy to web directory
cp "$ADDON_DIR/vpn-route-domain.asp" "/www/user/$am_webui_page"

# Modify menu
if [ ! -f /tmp/menuTree.js ]; then
    cp /www/require/modules/menuTree.js /tmp/
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

# Add to VPN menu
sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$am_webui_page\", tabName: \"VPN Domains\"}," /tmp/menuTree.js
umount /www/require/modules/menuTree.js && mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

# Setup service-event handler
if [ ! -f "$SCRIPT_DIR/service-event" ]; then
    echo "#!/bin/sh" > "$SCRIPT_DIR/service-event"
    chmod +x "$SCRIPT_DIR/service-event"
fi

if ! grep -q "vpn-route-domain" "$SCRIPT_DIR/service-event"; then
    echo "" >> "$SCRIPT_DIR/service-event"
    echo "### vpn-route-domain start ###" >> "$SCRIPT_DIR/service-event"
    echo "/jffs/addons/vpn-route-domain/vpn-route-domain-service.sh \$*" >> "$SCRIPT_DIR/service-event"
    echo "### vpn-route-domain end ###" >> "$SCRIPT_DIR/service-event"
fi

# Setup services-start for persistence
if [ ! -f "$SCRIPT_DIR/services-start" ]; then
    echo "#!/bin/sh" > "$SCRIPT_DIR/services-start"
    chmod +x "$SCRIPT_DIR/services-start"
fi

if ! grep -q "vpn-route-domain" "$SCRIPT_DIR/services-start"; then
    echo "" >> "$SCRIPT_DIR/services-start"
    echo "### vpn-route-domain start ###" >> "$SCRIPT_DIR/services-start"
    echo "sleep 10 && sh /jffs/scripts/vpn-route-domain.sh fix-routing" >> "$SCRIPT_DIR/services-start"
    echo "### vpn-route-domain end ###" >> "$SCRIPT_DIR/services-start"
fi

echo ""
echo "Installation complete!"
echo "Access VPN Route Domain in the web UI under VPN > VPN Domains"