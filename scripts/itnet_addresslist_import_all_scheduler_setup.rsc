:log info "iTNet-AddressList-Import-All-Scheduler-Setup-start"
:local ok true
:local scriptName "iTNet-AddressList-Import-All"
:local schedulerName "iTNet-AddressList-Import-All"
:local startDate "jan/01/1970"
:local startTime "01:00:00"
:local scriptPolicy "ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon"
:do {
 :if ([:len [/system scheduler find where name=$schedulerName]] > 0) do={
  /system scheduler remove [find where name=$schedulerName]
 }
 :if ([:len [/system scheduler find where name="iTNet-import address lists"]] > 0) do={
  /system scheduler remove [find where name="iTNet-import address lists"]
 }
 :if ([:len [/system script find where name=$scriptName]] > 0) do={
  /system script remove [find where name=$scriptName]
 }
 /system script add name=$scriptName policy=$scriptPolicy source={
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
}
:if ($ok = true) do={
 :do { /import file-name=$fWhatsApp } on-error={ :set ok false; :log error "iTNet import whatsapp failed" }
}
:if ($ok = true) do={
 :do { /import file-name=$fTelegram } on-error={ :set ok false; :log error "iTNet import telegram failed" }
}
:if ([:len [/file find where name=$fIran]] > 0) do={ /file remove [find where name=$fIran] }
:if ([:len [/file find where name=$fWhatsApp]] > 0) do={ /file remove [find where name=$fWhatsApp] }
:if ([:len [/file find where name=$fTelegram]] > 0) do={ /file remove [find where name=$fTelegram] }
:if ($ok = true) do={
 :log info "iTNet-AddressList-Import-All-done"
} else={
 :log warning "iTNet-AddressList-Import-All-finished-with-errors"
}
 }
 /system scheduler add interval=1d name=$schedulerName on-event=$scriptName policy=$scriptPolicy start-date=$startDate start-time=$startTime
 :do {
  /system script run $scriptName
 } on-error={
  :set ok false
  :log error "iTNet-AddressList-Import-All immediate run failed"
 }
 :log info "iTNet-AddressList-Import-All-Scheduler-Setup-done"
} on-error={
 :set ok false
 :log error "iTNet-AddressList-Import-All-Scheduler-Setup-failed"
}
:if ($ok = false) do={
 :log warning "iTNet-AddressList-Import-All-Scheduler-Setup-finished-with-errors"
}
