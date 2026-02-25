:log info "iTNet-VPN-Mangle-Setup-start"
:local ok true
:local tableName "VPN"
:local c1 "iTNet-Mangle-VPNList-to-VPNRoute"
:local c2 "iTNet-Mangle-NotNoVPN-to-VPNRoute"
:do {
    :local tableId [/routing table find where name=$tableName]
    :if ([:len $tableId] = 0) do={
        /routing table add name=$tableName fib
        :set tableId [/routing table find where name=$tableName]
        :log info "iTNet routing table VPN created with fib"
    }
    :if ([:len $tableId] > 0) do={
        :if ([/routing table get $tableId fib] != true) do={
            /routing table set $tableId fib
            :log info "iTNet routing table VPN fib enabled"
        }
    }
} on-error={
    :set ok false
    :log error "iTNet failed to prepare routing table VPN"
}
:if ($ok = true) do={
    :do {
        :if ([:len [/ip firewall mangle find where comment=$c1]] > 0) do={
            /ip firewall mangle remove [/ip firewall mangle find where comment=$c1]
        }
        /ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=$tableName dst-address-list=VPN passthrough=no disabled=yes comment=$c1
    } on-error={
        :set ok false
        :log error "iTNet failed to create VPN-list mangle"
    }
}
:if ($ok = true) do={
    :do {
        :if ([:len [/ip firewall mangle find where comment=$c2]] > 0) do={
            /ip firewall mangle remove [/ip firewall mangle find where comment=$c2]
        }
        /ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=$tableName dst-address-list=!NO-VPN passthrough=no disabled=yes comment=$c2
    } on-error={
        :set ok false
        :log error "iTNet failed to create non-NO-VPN mangle"
    }
}
:if ($ok = true) do={
    :log info "iTNet-VPN-Mangle-Setup-done"
} else={
    :log warning "iTNet-VPN-Mangle-Setup-finished-with-errors"
}
