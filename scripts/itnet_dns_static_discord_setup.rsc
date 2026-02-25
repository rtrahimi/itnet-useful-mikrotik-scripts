:log info "iTNet-DNS-Static-Discord-Setup-start"
:local ok true
:local listName "VPN"
:local dnsForward "8.8.8.8"
:local ttlValue "1d"
:local subComment "iTNet-dc-fp-sub2al"
:local legacySubComment "iTNet-dc-sub2al"
:local legacyHostComment "iTNet-dc-host2al"
:local oldComment "codex-discord-detect-dns-v2"
:do {
    :if ([:len [/ip dns static find where comment=$subComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$subComment]
    }
    :if ([:len [/ip dns static find where comment=$legacySubComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$legacySubComment]
    }
    :if ([:len [/ip dns static find where comment=$legacyHostComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$legacyHostComment]
    }
    :if ([:len [/ip dns static find where comment=$oldComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$oldComment]
    }
    /ip dns static add name="discord.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discord.gg" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discordapp.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discordapp.net" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discord.media" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discordcdn.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="discordstatus.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
} on-error={
    :set ok false
    :log error "iTNet failed to apply Discord DNS static records"
}
:if ($ok = true) do={
    :log info ("iTNet-DNS-Static-Discord-Setup-done sub=" . [/ip dns static print count-only where comment=$subComment])
} else={
    :log warning "iTNet-DNS-Static-Discord-Setup-finished-with-errors"
}
