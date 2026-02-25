:log info "iTNet-DNS-Static-OpenAI-Setup-start"
:local ok true
:local listName "openai"
:local dnsForward "8.8.8.8"
:local ttlValue "1d"
:local subComment "iTNet-oa-sub2al"
:local hostComment "iTNet-oa-host2al"
:local oldComment "codex-openai-detect-dns-v2"
:local badRegexp "(^|\\.)openai\\.comcodex-openai-test"
:do {
    :if ([:len [/ip dns static find where regexp=$badRegexp]] > 0) do={
        /ip dns static remove [/ip dns static find where regexp=$badRegexp]
    }
    :if ([:len [/ip dns static find where comment=$subComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$subComment]
    }
    :if ([:len [/ip dns static find where comment=$hostComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$hostComment]
    }
    :if ([:len [/ip dns static find where comment=$oldComment]] > 0) do={
        /ip dns static remove [/ip dns static find where comment=$oldComment]
    }
    /ip dns static add name="openai.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="chatgpt.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="oaistatic.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="oaiusercontent.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="ct.sendgrid.net" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="featuregates.org" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="intercom.io" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="intercomcdn.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="statsig.com" type=FWD forward-to=$dnsForward ttl=$ttlValue match-subdomain=yes address-list=$listName comment=$subComment
    /ip dns static add name="challenges.cloudflare.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="featureassets.org" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="forwarder.workos.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="humb.apple.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="js.stripe.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="o207216.ingest.sentry.io" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="o33249.ingest.sentry.io" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="prodregistryv2.org" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="rum.browser-intake-datadoghq.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="setup.workos.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="cdn.workos.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="cdn.openaimerge.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="images.workoscdn.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="workos.imgix.net" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="statsigapi.net" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="events.statsigapi.net" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="chatgpt.livekit.cloud" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
    /ip dns static add name="register.appattest.apple.com" type=FWD forward-to=$dnsForward ttl=$ttlValue address-list=$listName comment=$hostComment
} on-error={
    :set ok false
    :log error "iTNet failed to apply OpenAI DNS static records"
}
:if ($ok = true) do={
    :log info ("iTNet-DNS-Static-OpenAI-Setup-done sub=" . [/ip dns static print count-only where comment=$subComment] . " host=" . [/ip dns static print count-only where comment=$hostComment])
} else={
    :log warning "iTNet-DNS-Static-OpenAI-Setup-finished-with-errors"
}
