#!/usr/bin/env bash

mkdir -p /etc/swss/config.d/

CFGGEN_PARAMS=" \
    -d \
    -y /etc/sonic/constants.yml \
    -t /usr/share/sonic/templates/switch.json.j2,/etc/swss/config.d/switch.json \
    -t /usr/share/sonic/templates/ipinip.json.j2,/etc/swss/config.d/ipinip.json \
    -t /usr/share/sonic/templates/ports.json.j2,/etc/swss/config.d/ports.json \
    -t /usr/share/sonic/templates/vlan_vars.j2 \
    -t /usr/share/sonic/templates/ndppd.conf.j2,/etc/ndppd.conf \
"
VLAN=$(sonic-cfggen $CFGGEN_PARAMS)

# Executed HWSKU specific initialization tasks.
if [ -x /usr/share/sonic/hwsku/hwsku-init ]; then
    /usr/share/sonic/hwsku/hwsku-init
fi

# Start arp_update and NDP proxy daemon when VLAN exists
if [ "$VLAN" != "" ]; then
    cp /usr/share/sonic/templates/arp_update.conf /etc/supervisor/conf.d/
    cp /usr/share/sonic/templates/ndppd.conf /etc/supervisor/conf.d/
fi

USE_PCI_ID_IN_CHASSIS_STATE_DB=/usr/share/sonic/platform/use_pci_id_chassis
ASIC_ID="asic$NAMESPACE_ID"
if [ -f "$USE_PCI_ID_IN_CHASSIS_STATE_DB" ]; then
    while true; do
        PCI_ID=$(sonic-db-cli -s CHASSIS_STATE_DB HGET "CHASSIS_ASIC_TABLE|$ASIC_ID" asic_pci_address)
        if [ -z "$PCI_ID" ]; then
            sleep 3
        else
            # Update CONFIG_DB asic_id
            if [[ $PCI_ID == ????:??:??.? ]]; then
                sonic-db-cli CONFIG_DB HSET 'DEVICE_METADATA|localhost' 'asic_id' ${PCI_ID#*:}
                break
            fi
        fi
    done
fi

exec /usr/local/bin/supervisord
