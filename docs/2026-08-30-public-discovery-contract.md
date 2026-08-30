# Orchestrate public discovery contract

The canonical public host is `https://orchestrateops.com`. Its nginx boundary
serves real text robots, XML sitemap, and IndexNow ownership endpoints before
the Flutter fallback.

The sitemap is an explicit inventory of stable public product, marketing,
pricing, policy, legal, evaluator, security, and FAQ routes. Dynamic journey
state and application routes are not enumerated. Customer execution,
agreements, invoices, payments, account state, authenticated client state,
operator/admin state, and API routes are excluded.

Unknown query state never creates a new canonical document and tracking
parameters never redefine canonical identity. After a successful deployment,
`node tool/notify_indexnow.mjs` hashes the canonical sitemap and sends one
notification only when the public inventory changes.

Native continuation is not modeled for this host unless a released supported
native application and a stable public destination authority exist. The public
URL remains the only canonical identity; no app URL system or forced store
redirect is created by discovery.
