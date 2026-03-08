:log info "iTNet-AddressList-Import-All-Scheduler-Setup-start"
:local ok true
:local schedulerName "iTNet-import address lists"
:do {
    :if ([:len [/system scheduler find where name=$schedulerName]] > 0) do={
        /system scheduler remove [find where name=$schedulerName]
    }
    /system scheduler add interval=1d name=$schedulerName on-event={
:log info "iTNet-AddressList-Import-All-start"
:local ok true
:local baseUrl "https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts"
:local fIran "iran_no_vpn.rsc"
:local fWhatsApp "whatsapp_vpn.rsc"
:local fTelegram "telegram_vpn.rsc"
:if ([:len [/file find where name=$fIran]] > 0) do={ /file remove [find where name=$fIran] }
:if ([:len [/file find where name=$fWhatsApp]] > 0) do={ /file remove [find where name=$fWhatsApp] }
:if ([:len [/file find where name=$fTelegram]] > 0) do={ /file remove [find where name=$fTelegram] }
:do { /tool fetch check-certificate=no mode=https keep-result=yes url=($baseUrl . "/" . $fIran) dst-path=$fIran } on-error={ :set ok false; :log error "iTNet fetch iran failed" }
:do { /tool fetch check-certificate=no mode=https keep-result=yes url=($baseUrl . "/" . $fWhatsApp) dst-path=$fWhatsApp } on-error={ :set ok false; :log error "iTNet fetch whatsapp failed" }
:do { /tool fetch check-certificate=no mode=https keep-result=yes url=($baseUrl . "/" . $fTelegram) dst-path=$fTelegram } on-error={ :set ok false; :log error "iTNet fetch telegram failed" }
:if ([:len [/file find where name=$fIran]] = 0) do={ :set ok false; :log error "iTNet iran file missing" }
:if ([:len [/file find where name=$fWhatsApp]] = 0) do={ :set ok false; :log error "iTNet whatsapp file missing" }
:if ([:len [/file find where name=$fTelegram]] = 0) do={ :set ok false; :log error "iTNet telegram file missing" }
:if ($ok = true) do={
    :do { /import file-name=$fIran } on-error={ :set ok false; :log error "iTNet import iran failed" }
    :do { /import file-name=$fWhatsApp } on-error={ :set ok false; :log error "iTNet import whatsapp failed" }
    :do { /import file-name=$fTelegram } on-error={ :set ok false; :log error "iTNet import telegram failed" }
}
:if ($ok = true) do={
    :if ([:len [/file find where name=$fIran]] > 0) do={ /file remove [find where name=$fIran] }
    :if ([:len [/file find where name=$fWhatsApp]] > 0) do={ /file remove [find where name=$fWhatsApp] }
    :if ([:len [/file find where name=$fTelegram]] > 0) do={ /file remove [find where name=$fTelegram] }
    :log info "iTNet-AddressList-Import-All-done"
} else={
    :log warning "iTNet-AddressList-Import-All-finished-with-errors"
}
    } policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=1970-01-01 start-time=01:00:00
    :log info "iTNet-AddressList-Import-All-Scheduler-Setup-done"
} on-error={
    :set ok false
    :log error "iTNet-AddressList-Import-All-Scheduler-Setup-failed"
}
:if ($ok = false) do={
    :log warning "iTNet-AddressList-Import-All-Scheduler-Setup-finished-with-errors"
}
