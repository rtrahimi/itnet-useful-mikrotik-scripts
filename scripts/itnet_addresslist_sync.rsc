:log info "iTNet-AddressList-Scheduler-Setup-start"
:local ok true
:local syncName "iTNet-AddressList-Sync"
:local startDate "jan/01/1997"
:local startTime "05:00:00"
:do {
    :if ([:len [/system scheduler find where name=$syncName]] > 0) do={
        /system scheduler remove [/system scheduler find where name=$syncName]
    }
    :if ([:len [/system script find where name=$syncName]] > 0) do={
        /system script remove [/system script find where name=$syncName]
    }
    /system scheduler add name=$syncName start-date=$startDate start-time=$startTime interval=1d disabled=no on-event={
:log info "iTNet-AddressList-Sync-start"
:local ok true
:local f1 "itnet_whatsapp_vpn.rsc"
:local f2 "itnet_telegram_vpn.rsc"
:local f3 "itnet_iran_no_vpn.rsc"
:if ([:len [/file find where name=$f1]] > 0) do={ /file remove [find where name=$f1] }
:if ([:len [/file find where name=$f2]] > 0) do={ /file remove [find where name=$f2] }
:if ([:len [/file find where name=$f3]] > 0) do={ /file remove [find where name=$f3] }
:do { /tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/daily-meta-address-list/main/whatsapp_vpn.rsc" dst-path=$f1 } on-error={ :set ok false; :log error "iTNet fetch whatsapp failed" }
:do { /tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/daily-telegram-address-list/main/telegram_vpn.rsc" dst-path=$f2 } on-error={ :set ok false; :log error "iTNet fetch telegram failed" }
:do { /tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/daily-iran-address-list/main/iran_no_vpn.rsc" dst-path=$f3 } on-error={ :set ok false; :log error "iTNet fetch iran failed" }
:if ([:len [/file find where name=$f1]] = 0) do={ :set ok false; :log error "iTNet whatsapp file missing" }
:if ([:len [/file find where name=$f2]] = 0) do={ :set ok false; :log error "iTNet telegram file missing" }
:if ([:len [/file find where name=$f3]] = 0) do={ :set ok false; :log error "iTNet iran file missing" }
:if ($ok = true) do={
    :do { /ip firewall address-list remove [find where comment="iTNet-Whatsapp"]; /import file-name=$f1 } on-error={ :set ok false; :log error "iTNet apply whatsapp failed" }
    :do { /ip firewall address-list remove [find where comment="iTNet-Telegram"]; /import file-name=$f2 } on-error={ :set ok false; :log error "iTNet apply telegram failed" }
    :do { /ip firewall address-list remove [find where comment="iTNet-IranAddressList"]; /import file-name=$f3 } on-error={ :set ok false; :log error "iTNet apply iran failed" }
} else={
    :log warning "iTNet-AddressList-Sync aborted keep existing lists"
}
:if ([:len [/file find where name=$f1]] > 0) do={ /file remove [find where name=$f1] }
:if ([:len [/file find where name=$f2]] > 0) do={ /file remove [find where name=$f2] }
:if ([:len [/file find where name=$f3]] > 0) do={ /file remove [find where name=$f3] }
:if ($ok = true) do={
    :log info ("iTNet-AddressList-Sync-done whatsapp=" . [/ip firewall address-list print count-only where comment="iTNet-Whatsapp"] . " telegram=" . [/ip firewall address-list print count-only where comment="iTNet-Telegram"] . " iran=" . [/ip firewall address-list print count-only where comment="iTNet-IranAddressList"])
} else={
    :log warning "iTNet-AddressList-Sync-finished-with-errors"
}
    }
    /system scheduler enable [/system scheduler find where name=$syncName]
    :log info "iTNet scheduler configured daily at 05:00 starting 1997-01-01"
} on-error={
    :set ok false
    :log error "iTNet failed to configure address-list scheduler"
}
:if ($ok = true) do={
    :log info "iTNet-AddressList-Scheduler-Setup-done"
} else={
    :log warning "iTNet-AddressList-Scheduler-Setup-finished-with-errors"
}
