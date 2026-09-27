:log info "iTNet-AddressList-Import-Outside-Setup-start"
:local ok true
:local scriptName "iTNet-AddressList-Import-Outside"
:local schedulerName "iTNet-AddressList-Import-Outside"
:local startDate "jan/01/1970"
:local startTime "01:00:00"
:local scriptPolicy "ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon"
:do {
 :if ([:len [/system scheduler find where name=$schedulerName]] > 0) do={
  /system scheduler remove [find where name=$schedulerName]
 }
 :if ([:len [/system scheduler find where name="iTNet-AddressList-Import-All"]] > 0) do={
  /system scheduler remove [find where name="iTNet-AddressList-Import-All"]
 }
 :if ([:len [/system scheduler find where name="iTNet-AddressList-Import-Iran"]] > 0) do={
  /system scheduler remove [find where name="iTNet-AddressList-Import-Iran"]
 }
 :if ([:len [/system scheduler find where name="iTNet-import address lists"]] > 0) do={
  /system scheduler remove [find where name="iTNet-import address lists"]
 }
 :if ([:len [/system script find where name=$scriptName]] > 0) do={
  /system script remove [find where name=$scriptName]
 }
 :if ([:len [/system script find where name="iTNet-AddressList-Import-All"]] > 0) do={
  /system script remove [find where name="iTNet-AddressList-Import-All"]
 }
 :if ([:len [/system script find where name="iTNet-AddressList-Import-Iran"]] > 0) do={
  /system script remove [find where name="iTNet-AddressList-Import-Iran"]
 }
 /system script add name=$scriptName policy=$scriptPolicy source={
 :log info "iTNet-AddressList-Import-Outside-start"
 :local ok true
 :local baseUrl "https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts"
 :local fSpamhaus "itnet-spamhaus_auto_block.rsc"
 :if ([:len [/file find where name=$fSpamhaus]] > 0) do={ /file remove [find where name=$fSpamhaus] }
 :do { /tool fetch check-certificate=no mode=https keep-result=yes url=($baseUrl . "/" . $fSpamhaus) dst-path=$fSpamhaus } on-error={ :set ok false; :log error "iTNet fetch spamhaus failed" }
 :if ([:len [/file find where name=$fSpamhaus]] = 0) do={ :set ok false; :log error "iTNet spamhaus file missing" }
 :if ($ok = true) do={
  :do { /import file-name=$fSpamhaus } on-error={ :set ok false; :log error "iTNet import spamhaus failed" }
 }
 :if ([:len [/file find where name=$fSpamhaus]] > 0) do={ /file remove [find where name=$fSpamhaus] }
 :if ($ok = true) do={
  :log info "iTNet-AddressList-Import-Outside-done"
 } else={
  :log warning "iTNet-AddressList-Import-Outside-finished-with-errors"
 }
 }
 /system scheduler add interval=1d name=$schedulerName on-event=$scriptName policy=$scriptPolicy start-date=$startDate start-time=$startTime
 :do {
  /system script run $scriptName
 } on-error={
  :set ok false
  :log error "iTNet-AddressList-Import-Outside immediate run failed"
 }
 :log info "iTNet-AddressList-Import-Outside-Setup-done"
} on-error={
 :set ok false
 :log error "iTNet-AddressList-Import-Outside-Setup-failed"
}
:if ($ok = false) do={
 :log warning "iTNet-AddressList-Import-Outside-Setup-finished-with-errors"
}
