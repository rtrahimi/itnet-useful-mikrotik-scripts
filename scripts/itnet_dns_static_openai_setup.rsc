:log info "iTNet-DNS-Static-OpenAI-Setup-start"
:local ok true
:local listName "VPN"
:local dnsForward "8.8.8.8"
:local ttlValue "1d"
:local subComment "iTNet-oa-fp-sub2al"
:local legacySubComment "iTNet-oa-sub2al"
:local legacyHostComment "iTNet-oa-host2al"
:local oldComment "codex-openai-detect-dns-v2"
:local badRegexp "(^|\\.)openai\\.comcodex-openai-test"
:do {
    :if ([:len [/ip dns static find where regexp=$badRegexp]] > 0) do={
        /ip dns static remove [/ip dns static find where regexp=$badRegexp]
    }
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
    /ip dns static add name="openai.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="chatgpt.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="oaistatic.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="oaiusercontent.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="openai.org" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="sora.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
} on-error={
    :set ok false
    :log error "iTNet failed to apply OpenAI DNS static records"
}
:if ($ok = true) do={
    :log info ("iTNet-DNS-Static-OpenAI-Setup-done sub=" . [/ip dns static print count-only where comment=$subComment])
} else={
    :log warning "iTNet-DNS-Static-OpenAI-Setup-finished-with-errors"
}
