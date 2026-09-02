# Adversarial Seam Review — ARCHITECTURE-SPINE.md (Atendimento Nouvet, Piloto)

**Reviewer stance:** adversarial. For each AD, I constructed a scenario where two units built one level down — two sub-workflows, or two developers implementing two different PRD §4 Features — each obey the AD's Rule **to the letter**, yet still build incompatibly. A "clash" here means: divergent shared-data shape, two owners of one entity, a state-mutation race the Rule doesn't prevent, or an ambiguous term two people would read differently.

**Verdict:** the spine is directionally sound (config-as-data, tool-subworkflow, lock-based debounce are all the right primitives, lifted from a proven reference), but it has five load-bearing gaps that will bite during a 10-day build with more than one developer touching the code: no crash/timeout recovery for the AD-5 lock, no per-customer-identity guard against duplicate CRM cards, an AD-4 write-tool ban that a compliant read-only tool can quietly erode, an unassigned home for rotating OAuth tokens between AD-1 and AD-2, and an unresolved single-agent-vs-multi-agent orchestration model that several other ADs silently assume an answer to.

---

## AD-1 — Config-as-Data

**Rule:** every team-editable value lives in a Postgres table, read fresh every turn; never hardcoded, never cached.

### Scenario
Dev A builds the Exames sub-workflow (FR-15/16: "verifica se o exame requer anestesia"). The list of exam types that require anesthesia is exactly the kind of business rule that changes over time (a new exam type gets added, a threshold changes) — but AD-1's Rule enumerates specific categories ("tom, dados institucionais, limiares de tempo, sinais de alerta clínico, destinatários de emergência") and does **not** mention "regras de classificação de exame." Dev A reads the enumeration as exhaustive-by-example and hardcodes the anesthesia-required exam list as a `switch`/`if` node inside the Exames sub-workflow — technically not in the agent's `systemMessage`, so the AD-1 *Prevents* clause ("personalização hardcoded no systemMessage... ou em nó do n8n") is debatable: is a business-rule lookup table "personalização"? Dev A argues no.

Dev B, building the funnel-stage movement for FR-23 (mover card entre etapas automaticamente), treats `pipeline_id`/`stage_id` mapping the same way — hardcodes RD CRM stage IDs directly into the CRM tool sub-workflow's node parameters, reasoning that stage IDs are "integration wiring," not "personalização," and AD-1's enumerated list doesn't mention funnel stages either.

Both builders satisfy AD-1's Rule under a narrow reading of "personalização." Neither table gets a config row for exam-anesthesia rules or stage-ID mapping. Six weeks later, Nouvet asks to add a new exam type or rename a funnel stage — and it's a flow-node edit, exactly what AD-1 exists to prevent, because the Rule's enumeration reads as a closed list rather than an open principle.

**Severity:** Medium. **Fix:** reword AD-1's Rule from an enumerated list to an open principle — "todo dado que reflete uma regra de negócio do Nouvet, não uma decisão técnica de implementação, vive em Postgres" — and explicitly name funnel-stage mapping and any classification/threshold list (anesthesia-required exams, escalation triggers, etc.) as in-scope, not just the five examples given. This also closes the FR-23 gap already flagged as unresolved in PRD Open Question #4 — right now nothing in the spine tells whichever developer builds FR-23 where the stage mapping should live.

---

## AD-2 — Credentials only in the native vault

**Rule:** every external API credential is an n8n credential in the vault; config tables hold operational data only, never secrets.

### Scenario — the real boundary case: rotating OAuth tokens
AD-8's own Rule states the RD CRM `refresh_token` **rotates on every renewal** and the old one must be discarded or the next renewal fails. That's a strong hint that whoever builds the CRM integration needs *somewhere* to persist the current `refresh_token` across executions, updated in place.

Dev A builds the CRM tool sub-workflow using n8n's native `OAuth2Api` generic credential type and lets n8n's own credential-refresh mechanism handle it — the refreshed token is written back into the encrypted credential store transparently. This satisfies AD-2 cleanly.

Dev B, building a *different* CRM-touching sub-workflow (say, the Task-creation tool for AD-6's "cliente novo sem SimplesVet" path) independently, doesn't reuse Dev A's credential wiring — maybe because n8n's generic OAuth2 credential UI doesn't expose the "refresh_token always changes" quirk clearly, or because Dev B needs the token from a Code/Function node for a custom retry loop. Dev B implements a manual refresh: call the OAuth endpoint, get the new `access_token`/`refresh_token` pair, and persist the current `refresh_token` in a Postgres table (e.g., a new `integracoes_tokens` row) so it's readable across executions and workflows. Dev B can defend this as compliant: the *original* credential (`client_id`/`client_secret`) is still in the vault (AD-2's literal requirement); the *rotating derived token* isn't obviously "credential" in the same sense as a static API key, and AD-1's Rule doesn't forbid storing "operational state" in Postgres — a rotating token could be read as operational state, not a secret, since it's system-managed rather than "editável pela equipe."

Now there are two independently-refreshed copies of the RD CRM auth state: n8n's internal credential store (updated by Dev A's flow) and a Postgres table (updated by Dev B's flow) — each renewal invalidates the *other* copy's `refresh_token` (per AD-8's own rule: "renovar... sempre substitui o refresh_token anterior... guardar o antigo quebra a próxima renovação"). Whichever sub-workflow refreshes second silently breaks the other's next call, with a 2-hour-expiry blast radius (AD-8) that will surface as a mysterious, intermittent 401 in production — exactly the kind of bug that's hard to reproduce because it depends on refresh timing race.

**Severity:** Medium-High. This is the single clearest case where AD-1 and AD-2 do **not** unambiguously assign a field to one table — a rotating, system-managed secret sits exactly on the boundary the review was asked to probe.

**Fix:** add an explicit sentence to AD-2: "nenhuma outra cópia de token/refresh_token de nenhuma integração pode existir fora do cofre nativo — inclusive tokens derivados/rotativos; todo sub-workflow que precisa de um token OAuth2 usa a mesma n8n credential nomeada, nunca lê/escreve o token em tabela própria." Optionally also mandate that only ONE sub-workflow ("porta única" pattern, same spirit as AD-4/AD-8) is allowed to perform the token refresh, with all other CRM-touching sub-workflows calling through it rather than managing auth independently.

---

## AD-3 — Two Postgres databases, least privilege

**Rule:** one Postgres server, two databases (n8n internal vs. app), each with its own least-privilege user.

### Scenario
The Rule specifies granularity at the **database** level ("cada uma com usuário próprio de privilégio mínimo" — one user per *base*), not at the table level. Dev A, provisioning the app database, creates a single `secretaria_app` role with full CRUD on every table in the app DB — config, queue, lock, and the new customer/pet identity table — and calls this "privilégio mínimo" because it's already scoped to just the app DB, not the n8n internal DB. This is a literal, defensible reading of the Rule.

Dev B, building the identity table (AD-6) that holds customer/pet PII pulled from SimplesVet — flagged in the spine's own Deferred section as a growing LGPD retention liability — reasonably expects that PII table to be reachable by a *narrower* credential than the pure-plumbing debounce queue (`n8n_fila_mensagens`) or lock table (`n8n_status_atendimento`), which hold no PII. Dev B assumes finer-grained roles are coming and doesn't push back on Dev A's single shared role.

Nothing in AD-3 as written distinguishes "least privilege across the two databases" from "least privilege within the app database, by data sensitivity" — both developers comply with the Rule, and the PII table ends up reachable by the same credential as debounce plumbing, unnecessarily widening blast radius on the one table the spine already flags as an LGPD open question.

**Severity:** Low-Medium (security hygiene, not a functional break). **Fix:** extend AD-3's Rule to require a separate, narrower-scoped role for the identity/PII table specifically, not just database-level separation.

---

## AD-4 — Agent never calls an external integration directly

**Rule:** every agent-callable action is a separate `toolWorkflow`. No agenda write-tool (create/update/cancel) is wired to the agent in the Pilot.

*(See dedicated AD-4/AD-9 section below — the two ADs are effectively inseparable here, per the task's own framing.)*

---

## AD-5 — Debounce + lock at ingress

**Rule:** inbound message enters a queue keyed by phone; session locks (`lock_conversa`) before processing; short wait + requery; only the execution triggered by the *last* message of the batch proceeds, processing everything aggregated.

### Scenario — no described unlock path on crash
The Rule (and its source pattern in `config-postgres.md`) describes only the happy path: lock → process → unlock. Neither the AD-5 text nor the `n8n_status_atendimento` schema (`lock_conversa`, `aguardando_followup`, `numero_followup`, `updated_at`) includes a TTL, a watchdog, or any Rule requiring the unlock to happen in a `finally`/error-branch. This is **not called out even in the Deferred section** — it's silently assumed to be happy-path.

Dev A implements the ingress workflow exactly per the reference pattern: lock at the start, unlock at the very end of the successful run. Dev B, building the CRM Task-creation tool sub-workflow that AD-6 requires for unregistered customers, calls the RD CRM API (which, per the `crm.md` reference, can return `429`/`500`/`403`, and whose OAuth token can be mid-expiry per AD-8) without wrapping the call in error handling that guarantees the ingress workflow still reaches its unlock step. A transient RD CRM outage or a timed-out Microsoft Graph call inside the "prepared base" (AD-9) mid-turn throws before the agent's execution reaches its final unlock node.

Both developers followed AD-5's Rule literally — it only says "trava antes de processar" and implies unlock at completion; it says nothing about what happens on failure. Result: `lock_conversa=true` is stuck forever for that phone number. Every subsequent message from that customer enters the queue and is held by the requery step (which, per the pattern, waits for the lock to clear) — the customer becomes **permanently unable to get an automated response**, which is the single worst possible failure mode for a product whose entire stated purpose is "garantir que ninguém fique sem resposta." This is worse than most other seams in this review because it silently defeats NFR-1/SM-2/SM-3 exactly at the moment something goes wrong — the scenario where the safety net matters most.

**Severity:** Critical. This is a classic seam bug and the spine currently has zero mention of it, not even as an explicit Deferred item — it just isn't addressed.

**Fix (recommend at minimum a Deferred entry, ideally a Rule):** either (a) add a Rule requiring every workflow that participates in AD-5's lock — the main agent execution and every `toolWorkflow` it calls — to run under an n8n error-workflow (`Error Trigger` bound at the workflow level) that force-clears `lock_conversa` on any unhandled exception, or (b) add a TTL-based recovery: the requery step in ingress also force-clears any lock whose `updated_at` is older than N minutes before re-locking, treating a stale lock as abandoned rather than active. (b) is simpler to build in 10 days and doesn't require every sub-workflow author to remember error handling — recommend making (b) the actual Rule and (a) optional defense-in-depth.

---

## AD-6 — Postgres identity is complementary to the RD CRM card

**Rule:** Postgres resolves fast operational identity (seeded by one-time SimplesVet import + new direct registrations); RD CRM card remains the funnel/negotiation record; a new customer with no SimplesVet record gets a **Task** on the CRM card asking for manual registration (not a label).

*(See dedicated AD-6/AD-8 section below.)*

---

## AD-7 — Single messaging channel: RD Station Conversas

**Rule:** all inbound/outbound passes through RD Conversas; send via `POST /v2/messages/{contact_id}/send` (form-urlencoded); receive via Tallos-panel webhook; no native typing indicator or paced send — if pacing is needed, it's a `Wait` sequence in n8n itself.

### Scenario
AD-7 leaves pacing as discretionary ("se necessário simular ritmo humano"), and doesn't say whether a paced multi-message reply happens **before or after** AD-5 releases `lock_conversa`.

Dev A (building the Recepção flow, which tends to produce longer first-contact explanations) implements pacing by unlocking the session immediately once the agent's answer is computed, then firing the paced `Wait`-delimited sequence of sends asynchronously. This keeps the lock window short (good for AD-5 throughput) but means a fast follow-up message from the same customer can start a **new** ingress execution while the first reply is still trickling out in pieces — nothing orders the two message streams relative to each other, so the customer can see the tail of the old paced reply interleaved with the start of the new one.

Dev B (building Care Center, whose replies are typically short) instead holds the lock through the entire pacing sequence, on the reasonable assumption that "processing" (which AD-5 says the lock covers) isn't finished until the full reply has been sent. For a long reply (e.g., Exames' detailed anesthesia/pre-op explanation) this inflates the lock window well past what AD-5's "short wait + requery" language implies, delaying processing of anything the customer sends next.

Both are literal, defensible readings of "processamento" under AD-5 combined with AD-7's undefined pacing boundary — and they produce different, inconsistent latency and message-ordering behavior depending on which sub-workflow a given conversation happens to route through. (FR-39's clarification that the SLA clock stops at the *first* automated message, not the last, saves the NFR-1/SM-2 metric from this ambiguity — but the lock-duration and message-interleaving risk stands on its own, independent of the metric.)

**Severity:** Medium. **Fix:** AD-5 or AD-7 should state explicitly whether the lock is held through any outbound pacing sequence, and — if not — how message ordering across two rapidly-consecutive executions for the same phone is guaranteed (e.g., a per-phone outbound send queue, distinct from the inbound debounce queue).

---

## AD-8 — RD Conversas and RD CRM are always two distinct integrations

**Rule:** two credentials, always; normalize phone format before matching (CRM uses clean E.164, Conversas uses spaces/dashes); refresh_token always replaces the previous one.

*(See dedicated AD-6/AD-8 section below for the concurrency angle; the token-rotation angle is covered under AD-1/AD-2 above.)*

### Additional scenario — normalization isn't centralized
AD-8's Rule states *that* normalization must happen but not *where* — which layer owns it, or what the canonical stored format is. Dev A (CRM tool sub-workflow) normalizes to clean E.164 with the `+55` country code. Dev B (a different sub-workflow that also needs to compare a Conversas-side phone against the Postgres identity table) writes its own normalization pass, stripping only whitespace/dashes but not accounting for Brazil's well-known mobile "9th digit" ambiguity (a number stored with vs. without the extra leading `9` on the subscriber portion). Two independently-written normalizers is exactly the kind of divergence that produces silent false-negative matches — the same real customer treated as "not found" by one sub-workflow and "found" by another. This compounds directly into the AD-6 duplicate-card risk below.

**Severity:** Medium. **Fix:** normalization should be a single shared function/sub-workflow (or a Postgres function used by every query), not re-implemented per integration point, with the canonical stored format specified in the Rule itself (not left implicit).

---

## AD-9 — Calendar integration: prepared, not exercised live

**Rule:** when write is eventually enabled, access is via the native Microsoft Outlook node, credential scoped `Calendars.ReadWrite`. In the Pilot, only the base gets built (auth, per-professional calendar mapping) — no active create/update/cancel tool on the agent (per AD-4).

*(See dedicated AD-4/AD-9 section immediately below — this is the pairing the task explicitly asked to stress hardest.)*

---

## AD-10 — Pinned stack, no version drift

**Rule:** `postgres:16-alpine` on both VPS; `n8nio/n8n:2.14.2` pinned explicitly in `docker-compose.yml`, never `latest`.

### Scenario
The Rule pins by **tag**, not by digest. Docker tags are not immutable for base images like `-alpine` variants — Docker Hub republishes security patches under the same tag over time (this is far less true for n8n's own semver-style release tags, but the Rule pins `postgres:16-alpine` the same way). Dev A stands up the Dev VPS on day 1 of the Pilot, pulling `postgres:16-alpine` as it existed that day. The Prod VPS (per the spine's own Structural Seed, "provisionada só no go-live") is provisioned by Dev B eight days later, pulling the "same" tag — which may have been silently repatched upstream in the interim. Both developers followed AD-10's Rule to the letter (same tag string in both `docker-compose.yml` files); the images are not guaranteed byte-identical, which is precisely the failure mode AD-10's own *Prevents* clause names ("container recriado puxando versão diferente da testada").

**Severity:** Low. **Fix:** either pin by digest (`postgres:16-alpine@sha256:...`) for the Prod cutover specifically, or explicitly accept tag-only pinning as sufficient residual risk and say so, rather than let the *Prevents* clause overstate what the Rule actually guarantees.

---

## Deep-dive: AD-4 / AD-9 — does "prepared base" quietly become a half-wired live tool?

This is the pairing the task asked to stress hardest, and it's the review's second-most serious finding after the AD-5 lock gap.

**The literal gap:** AD-4's Rule bans *"nenhuma tool de escrita de agenda (criar/atualizar/cancelar evento)"* — a **write**-tool ban, stated explicitly and only about writes. AD-9 describes the Pilot's calendar work as building "autenticação, mapeamento de calendário por profissional" — but the natural first sub-workflow to build while wiring that up is `Buscar Janelas` (read availability), the read-only counterpart from the reference pattern (`03 - Buscar Janelas.json`). Nothing in AD-4 or AD-9 forbids connecting a **read-only** availability-check tool to the agent as an active `toolWorkflow`.

**The scenario:** Dev A, building the Care Center flow's "prepared base" under AD-9, wires up `Buscar Janelas` as a live tool on the agent — reasoning that checking availability is strictly informational, and giving the agent the ability to say "profissional X está livre terça às 14h" measurably improves the collected-preference quality that FR-12 asks for, and doesn't create any reservation (satisfies AD-4's write ban to the letter, satisfies AD-9's Rule about node/credential choice to the letter). Dev B, building the Consultas flow from the same PRD section, reads the **PRD** more literally — FR-12's own edge case states explicitly: *"mesmo quando o profissional preferido claramente não teria horário, essa checagem e a sugestão de alternativa ficam a cargo do humano que assume o card, não da IA"* — and therefore builds AD-9's base fully dormant, with no tool wired to either agent at all.

Neither developer violates any AD as written. But now the Care Center and Consultas flows behave inconsistently in production — one setor's agent silently starts giving availability opinions the PRD explicitly reserves for the human, and the other doesn't — and the divergence traces back to the fact that **the constraint the PRD actually wants ("no availability-checking by the AI, not just no reservation") lives only in a PRD edge-case note, not in AD-4's Rule text**, which the architecture layer is supposed to be the binding contract for.

**The sharper risk — credential scope already grants write, day one:** AD-9's Rule itself directs the eventual credential to scope `Calendars.ReadWrite`. Microsoft Graph app registrations typically need their target scope defined at consent time; re-consenting later to add scope is its own operation. A developer provisioning "the base" during the Pilot has every practical reason to request `Calendars.ReadWrite` **now**, matching what AD-9 says will eventually be needed, rather than provisioning `Calendars.Read` now and re-authorizing later. That means the deployed n8n credential is fully capable of writing to the calendar from day one of the Pilot — the only thing standing between that credential and an actual reservation is **which `toolWorkflow` nodes happen to be attached to the agent's tool list**, a purely procedural, workflow-editor-level convention with no technical enforcement. A developer testing the `04 - Criar Evento`-equivalent sub-workflow end-to-end during the Pilot ("just to prove the base works") who forgets to detach it before demo or go-live is one missed step away from a live, unauthorized write — and AD-4/AD-9 as written provide no automatic guard against that, only the discipline of the person editing the agent's tool list.

**Severity:** High.

**Recommended fixes (both, not either/or):**
1. **Tighten AD-4's Rule text** from "no write-tool" to: *"nenhuma tool de agenda — leitura ou escrita — fica ligada ao agente principal ou a qualquer Agente de Setor no Piloto; checagem de disponibilidade, como reserva, é manual pelo humano (FR-12 edge case)."* This makes the PRD's actual intent (human-only availability checks) an architectural Rule instead of leaving it recoverable only by reading the PRD's edge-case prose.
2. **Scope the credential to `Calendars.Read` during the Pilot**, and add an explicit sentence to AD-9: elevating to `Calendars.ReadWrite` is a deliberate, dated action taken only when the write-tool is intentionally activated post-Pilot — not a day-one default. This converts the boundary from a procedural convention (don't wire the node) into a technical one (the credential can't write even if the node gets wired by accident).

---

## Deep-dive: AD-6 / AD-8 — can two flows race to create the same CRM card/contact?

This is the pairing the task asked to stress hardest alongside AD-4/AD-9, and it surfaces the review's second-highest-severity structural gap.

**The premise the task flagged, confirmed:** AD-5's lock is keyed by `session_id`/telefone — it serializes turns *for one phone number*, full stop. It says nothing about, and cannot by construction protect, **customer identity that spans more than one phone number** — which is exactly the situation FR-4 exists to name ("telefone identificado pertence a uma pessoa diferente do titular do cadastro, ex.: cônjuge").

**The scenario:** A Nouvet household shares one pet across two people, each with their own phone. Neither number is yet linked in the Postgres identity table to the pet (say, the SimplesVet import only ever captured the husband's landline, and the wife has never texted from her own cell before). After a stressful event, both message the Nouvet WhatsApp within seconds of each other, from their two distinct real phone numbers, each independently reaching the "no match" branch of FR-2.

- AD-5's lock does **not** create contention here — these are two different `telefone` values, so two different `session_id` locks, running fully concurrently by design.
- Both executions independently hit AD-6's Rule: "cliente novo sem registro no SimplesVet gera Task no card do RD CRM pedindo cadastro manual." Both are, individually, "new" by the only identity key either sub-workflow has (phone number) — this is not a formatting mismatch that AD-8's normalization rule could catch (these are two genuinely different phone numbers, not two spellings of the same one).
- Each execution — built as its own tool sub-workflow per AD-4's "uma ação = um workflow" — independently does the check-then-create pattern against RD CRM (`GET /contacts?filter=phone:...` finds nothing → `POST /contacts` creates one, then a Task is attached). Nothing in AD-6, AD-8, or AD-5 requires — or even mentions — a way to detect that these two near-simultaneous "new customer" writes are actually the same underlying household/pet.

**Result:** two CRM cards for one customer/pet, both correctly built per every AD's literal Rule. This directly undermines FR-20 (single pipeline, single-card memory), SM-1 ("100 leads entram, 100 chegam ao CRM" — now potentially 100 leads produce 101+ cards, which arguably still isn't "SM-1 failure" numerically but is exactly the "cliente fantasma" duplication FR-21 was written to prevent, just via a different door), and NFR-3 (a fragmented, not append-only-coherent, history for that customer).

**A second, narrower version of the same hole — retry, not two people:** the LangChain agent's own tool-call retry behavior (on a transient RD CRM `429`/`500`/timeout, per `crm.md`'s documented error surface) can invoke the *same* Task-creation or card-creation tool twice for the *same* turn if the sub-workflow author didn't design the create-call to be idempotent (e.g., check-then-create without a unique constraint, and without first checking "does an open Task already exist for this contact"). AD-6's Rule never states an idempotency requirement, so whether a given tool sub-workflow guards against double-invocation is left entirely to the individual developer's judgment — and different developers building different setor tools will make different calls.

**A third compounding factor — who owns writing the Postgres identity row?** AD-6 says the identity table is "alimentado por import único inicial do SimplesVet + novos cadastros diretos," but never states which sub-workflow is the single writer for "novos cadastros diretos." If both the Recepção-identification flow (which runs first, early in the conversation) and a later Agente de Setor flow (which might learn additional pet details AD-6's Recepção step didn't capture) are each allowed to UPSERT the identity row, two developers building those two flows independently could each write partial data without any merge discipline, risking a lost update under concurrent writes for the two-phone-number race above.

**Severity:** High.

**Recommended fixes:**
1. **New Rule (extend AD-6 or add AD-11):** "criação de contato/card no RD CRM para cliente não identificado é sempre feita por um único sub-workflow ('porta única de criação'), chamado por qualquer Agente de Setor via `toolWorkflow` — nunca replicada em múltiplos sub-workflows." This centralizes the check-then-create logic in one place where an idempotency guard (e.g., a short-lived advisory lock or a `SELECT ... FOR UPDATE` against the Postgres identity table keyed by a normalized-phone **and** a fuzzy household match, before ever calling the CRM) can actually be enforced once, instead of hoped-for in N independent implementations.
2. **Explicit ownership Rule for the identity table:** name exactly one sub-workflow (likely the Recepção/identification tool, since it runs first) as the sole writer of new identity rows; any Agente de Setor that discovers additional identity data calls back through that same sub-workflow rather than writing the table directly.
3. At minimum, if neither of the above fits the 10-day timeline, **move this explicitly into Deferred with the concrete failure mode named** (two phone numbers, one household, concurrent first contact → duplicate cards) rather than leaving it un-mentioned — the current spine doesn't flag this risk anywhere, not even as accepted/known.

---

## Capability → Architecture Map: gaps and a bigger question underneath it

### The `4.5 Fluxo Exames` row doesn't list AD-1
Covered above under AD-1 — the anesthesia-required exam list is a business rule with no assigned config-table home, and the Map's "4.5 ... AD-4 (sub-workflow de anexo)" entry doesn't flag AD-1 as also governing it. A developer building this Feature has no map signal that this data belongs in Postgres.

### The `4.7 Registro e Memória no CRM` row doesn't flag the FR-23 stage-mapping gap
"4.7 | AD-6, AD-8" — doesn't mention AD-1, even though FR-23 (automatic funnel-stage movement) needs *some* config source for the stage-ID mapping, and PRD Open Question #4 confirms this is explicitly still open. Same root cause as the AD-1 finding above.

### The bigger issue: single-agent vs. multi-agent is never actually decided, and several ADs silently assume an answer
The spine's **Design Paradigm** table describes one orchestration layer: *"Único ponto de decisão da conversa; nunca chama integração externa direto"* and the dependency diagram shows exactly one `Agent` box between `Ingress` and `Tools`. AD-1's Rule talks about "o `systemMessage` do agente" (singular). AD-4's Rule talks about "o agente principal" (singular, explicitly named "principal" as if distinguishing it from something else).

But the **PRD's own Glossário** defines two distinct roles with a real handoff between them: *"Recepcionista IA — agente de IA responsável pelo primeiro contato... e direcionamento ao Agente de Setor"* and *"Agente de Setor — agente de IA especializado que assume a conversa após o direcionamento da Recepcionista IA."* "Handoff" is itself a defined glossary term, explicitly including *"transferência de atendimento entre agentes de IA"* — the PRD is describing a multi-agent architecture, not a single orchestrator with internal branching.

**The scenario:** Dev A, building Feature 4.1 (Recepção), implements this literally as the reference pattern's `secretariav3-completo` structure suggests one could — a single `@n8n/n8n-nodes-langchain.agent` node whose `systemMessage` and tool list are dynamically assembled per turn based on the classified setor stored in state, satisfying AD-1's "single agent" framing and AD-4's diagram exactly. Dev B, building Feature 4.3 (Care Center) as a genuinely separate `Agente de Setor`, builds it as its own distinct LangChain agent node/workflow, invoked from the Recepcionista's agent as an "agent-as-tool" `toolWorkflow` call (a legitimate reading of AD-4's "toda ação... é um workflow separado, chamado via toolWorkflow") — each with its **own** `systemMessage`, and potentially its own memory scope.

Both are defensible readings of the spine as written, and they are **not the same architecture**:
- Under Dev A's model, AD-5's lock and `memoryPostgresChat` session apply to one continuous `session_id` for the whole conversation, and AD-1's config-read happens once per turn for one agent.
- Under Dev B's model, a handoff to an Agente de Setor is itself a tool call inside the locked window (fine under AD-5), but now there are potentially N different `systemMessage` assembly points (once per Agente de Setor), N different places AD-1's "read config every turn" Rule has to be independently implemented correctly, and an open question about whether the Setor agent shares the Recepcionista's `n8n_historico_mensagens` session_id or gets its own (with implications for FR-22/NFR-3's append-only, ordered history requirement, and for what "the agent" means every time AD-4 says "o agente principal nunca chama integração externa direto" — does that constraint bind only the Recepcionista, or every Agente de Setor too?).

If two developers pick different models for two different Features, the resulting system has inconsistent memory-session semantics, inconsistent config-read points, and an ambiguous locus for "the agent" that AD-4's core guarantee is written around. This is exactly the kind of architecture-shaping ambiguity that's cheap to close now (one sentence in the Design Paradigm section) and expensive to unwind once two Features are built on incompatible assumptions.

**Severity:** High. **Fix:** the spine needs one explicit sentence stating whether "Agente de Setor" is (a) the same agent node with dynamically swapped `systemMessage`/tool-list per classified setor, or (b) a distinct agent node per setor invoked as a tool by the Recepcionista, and — whichever is chosen — a Rule stating whether `session_id`/memory is shared across a handoff or reset, and whether AD-4's "agente principal nunca chama integração externa direto" binds every Agente de Setor or only the Recepcionista.

---

## Summary of recommended fixes

| # | Finding | Severity | Recommended action |
|---|---|---|---|
| 1 | AD-5 lock has no crash/timeout recovery path | Critical | Add TTL-based stale-lock recovery to the ingress requery step (or an error-workflow guarantee); make this an explicit Rule, not a silent assumption |
| 2 | AD-5's per-telefone lock can't prevent duplicate CRM cards for one customer contacting from two numbers; no idempotency on card/Task creation | High | Centralize CRM contact/card creation behind one "porta única" sub-workflow; name a single writer for the Postgres identity table |
| 3 | AD-4's write-tool ban doesn't cover a read-only availability-check tool; AD-9's credential scope grants write from day one | High | Tighten AD-4's Rule to ban read tools too (align with PRD FR-12 edge case); scope the Pilot credential to `Calendars.Read` only, elevate deliberately post-Pilot |
| 4 | Single-agent-vs-multi-agent orchestration model is never decided, though several ADs assume an answer | High | Add one explicit sentence to Design Paradigm naming the model and its session/memory implications |
| 5 | Rotating OAuth `refresh_token` has no clearly assigned home between AD-1 (operational state) and AD-2 (credential) | Medium-High | Extend AD-2 to explicitly forbid any secondary copy of a token, including derived/rotating ones, outside the vault |
| 6 | AD-8 phone normalization isn't centralized — divergent re-implementations risk false-negative identity matches, compounding finding #2 | Medium | Make normalization one shared function/sub-workflow with a stated canonical format |
| 7 | AD-1's Rule reads as an enumerated (closed) list, leaving business-rule data like FR-23 stage mapping and FR-16 exam/anesthesia rules unassigned | Medium | Reword AD-1 as an open principle; update Capability→Architecture Map rows for 4.5 and 4.7 to list AD-1 |
| 8 | AD-7's pacing (`Wait` sequences) leaves lock-duration and message-ordering-across-executions undefined | Medium | State explicitly whether pacing happens inside or outside the AD-5 lock window |
| 9 | AD-3's least-privilege Rule is stated at database granularity only, leaving the LGPD-flagged PII identity table reachable by the same role as pure plumbing tables | Low-Medium | Require a narrower role specifically for the identity table |
| 10 | AD-10 pins by tag, not digest; tags (especially `-alpine` base images) aren't strictly immutable over an 8-10 day window between dev and prod provisioning | Low | Pin by digest for the prod cutover, or explicitly accept the residual risk |

---

## Sources consulted
- `_bmad-output/planning-artifacts/architecture/architecture-atendimento-2026-09-01/ARCHITECTURE-SPINE.md` (full read)
- `_bmad-output/planning-artifacts/prds/prd-atendimento-2026-08-31/prd.md` (full read, §4/§6 given closest attention per instructions)
- `.claude/skills/n8n-agent-patterns/references/agente-e-subfluxos.md`
- `.claude/skills/n8n-agent-patterns/references/config-postgres.md`
- `.claude/skills/rd-station-api/references/conversas.md`
- `.claude/skills/rd-station-api/references/crm.md`
