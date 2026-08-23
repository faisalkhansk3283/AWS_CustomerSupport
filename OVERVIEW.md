# Project Overview: AI-Powered Customer Support Agent on AWS

## One-Line Summary (Elevator Pitch)
> "I built and deployed a production-grade AI customer support agent on AWS using Amazon Bedrock AgentCore — covering the full lifecycle from prototype to optimized production with authentication, authorization, observability, governance, and data-driven A/B testing."

---

## Role Alignment

**Primary roles this project qualifies you for:**
- AI/GenAI Engineer
- Cloud Solutions Architect (AWS)
- AI Platform Engineer
- MLOps / LLMOps Engineer

**Secondary overlap:**
- Backend Engineer (Python, APIs, microservices)
- Security Engineer (IAM, JWT, OAuth, Cedar policies)
- DevOps / Platform Engineer (IaC, CDK, CI/CD-ready deployments)

---

## Tech Stack (Complete)

| Category | Technology | What I used it for |
|----------|-----------|-------------------|
| **AI Model** | Claude Sonnet 4 (Anthropic) via Amazon Bedrock | Foundation model powering the agent's reasoning |
| **Agent Framework** | Strands Agents SDK (Python) | Orchestration layer — tools, memory, streaming |
| **Runtime Platform** | Amazon Bedrock AgentCore | Managed hosting, scaling, session management |
| **Tool Protocol** | MCP (Model Context Protocol) | Standardized agent-to-tool communication |
| **External Search** | Exa AI MCP Server | Web search capability for the agent |
| **Serverless Compute** | AWS Lambda | Backend tool logic (warranty check, refund processing) |
| **API Gateway** | AgentCore Gateway | Centralized tool routing, auth, policy enforcement |
| **Authentication** | Amazon Cognito + JWT | User identity, token issuance, OIDC validation |
| **Authorization** | Cedar Policy Language | Fine-grained, deterministic access control rules |
| **Memory** | AgentCore Memory (Semantic + Summarization) | Cross-session user context and conversation history |
| **Observability** | OpenTelemetry (auto-instrumentation) + CloudWatch | Trace collection, log aggregation, metrics |
| **Quality Monitoring** | AgentCore Online Evaluations | LLM-as-a-Judge scoring (GoalSuccessRate, Correctness, ToolSelectionAccuracy) |
| **Optimization** | AgentCore Recommendations + A/B Testing | AI-driven prompt/tool optimization with statistical validation |
| **Infrastructure** | AWS CDK (L3 constructs) | Infrastructure-as-Code for all resources |
| **Frontend** | Flask + HTML/JS | Customer-facing chat interface |
| **Language** | Python 3.13 | Agent application code |
| **Auth Protocols** | OAuth 2.0 (client_credentials), JWT (Bearer), OIDC, SigV4 | Machine-to-machine and human auth flows |
| **Declarative Agents** | AgentCore Harness | Zero-code agent deployment (JSON config only) |
| **Container Runtime** | Custom Docker containers (ECR) | Pre-configured agent environments |
| **AWS SDK** | boto3 (Python) | Cognito auth calls, SSM parameter retrieval, Harness invocation (invoke_harness) |
| **Config Management** | AWS SSM Parameter Store | Secrets and configuration storage |
| **Monitoring** | Amazon CloudWatch | Log aggregation, trace visualization, metrics dashboards, alarms |
| **Version Control** | Git + GitHub | Source control and collaboration |
| **CLI Tooling** | AgentCore CLI (`agentcore`) | Project scaffolding, deployment, testing, monitoring |

---

## Architecture (Production State)

```
                                    ┌─────────────────────────────────┐
                                    │         Amazon Cognito           │
                                    │     (Identity Provider)          │
                                    │                                  │
                                    │  User Accounts → JWT tokens      │
                                    │  App Clients → OAuth tokens      │
                                    └──────────┬───────────────────────┘
                                               │ issues tokens
                                               ▼
┌──────────┐     JWT token      ┌──────────────────────────────────────────────────┐
│  Browser  │ ─────────────────→│            AgentCore Gateway                      │
│  (Flask)  │                   │          (my-gateway-secure)                      │
└──────────┘                    │                                                    │
                                │  ┌─────────────────────────────────────────────┐  │
                                │  │  Cedar Policy Engine (ENFORCE mode)          │  │
                                │  │  • refund_limit_policy (amount < $100)       │  │
                                │  │  • warranty_check_policy (permit all auth)   │  │
                                │  │  • refund_reason_policy (must be defective)  │  │
                                │  │  • BlockSensitiveRefundReasons (no emails)   │  │
                                │  └─────────────────────────────────────────────┘  │
                                │                                                    │
                                │  Targets:                                          │
                                │  ├─ WarrantyCheck → Lambda (check_warranty)        │
                                │  ├─ ProcessRefund → Lambda (process_refund)        │
                                │  └─ customer-support-ab → CustomerSupportAB        │
                                └────────────────────────┬─────────────────────────────┘
                                                         │
                          ┌──────────────────────────────┼───────────────────────────────┐
                          │                              │                               │
               ┌──────────▼──────────┐     ┌────────────▼────────────┐     ┌────────────▼────────────┐
               │  CustomerSupport     │     │  CustomerSupportAB       │     │  OrderResearchAgent     │
               │  (Production)        │     │  (A/B Testing)           │     │  (Harness - zero code)  │
               │                      │     │                          │     │                         │
               │  Auth: CUSTOM_JWT    │     │  Auth: IAM (GW only)     │     │  Auth: OAuth M2M        │
               │  Memory: Semantic +  │     │  Memory: None            │     │  Tools: Code Interpreter│
               │    Summarization     │     │  Config: Dynamic bundle  │     │  + Gateway + HITL       │
               │  Tools:              │     │  Eval: ABQualityMonitor   │     │  Skills: xlsx           │
               │  • get_return_policy │     └──────────────────────────┘     └─────────────────────────┘
               │  • get_product_info  │
               │  • Exa AI (web)      │        ┌──────────────────────┐
               │  • Gateway tools     │        │     CloudWatch        │
               │  Eval: QualityMonitor│        │  • Agent traces       │
               └──────────────────────┘        │  • Eval scores        │
                                               │  • Policy decisions   │
                         ┌─────────────┐       │  • A/B test metrics   │
                         │  AgentCore   │       └──────────────────────┘
                         │   Memory     │
                         │              │
                         │ /users/facts │
                         │ /summaries/  │
                         └─────────────┘
```

---

## What I Did (Minute-by-Minute Breakdown)

### Phase 1: Foundation (Labs 1-2)
**Time: ~30 min**

1. Scaffolded AgentCore project using CLI (`agentcore create`)
2. Selected Strands SDK + Python + Bedrock as model provider
3. Wrote two local tools: `get_return_policy` (lookup by category) and `get_product_info` (search by ID/name/keyword)
4. Defined product catalog and return policies as in-memory dictionaries
5. Configured system prompt for professional customer support behavior
6. Deployed to AgentCore Runtime (CodeZip packaging)
7. Added AgentCore Memory with two strategies:
   - **SEMANTIC** — stores user facts (e.g., "user prefers email communication")
   - **SUMMARIZATION** — compresses long conversations into summaries
8. Configured per-user memory isolation using session_id + actor_id
9. Tested multi-turn conversations with persistent recall

### Phase 2: Integration (Labs 3-4)
**Time: ~45 min**

10. Created AgentCore Gateway as a centralized tool hub
11. Added Lambda target (WarrantyCheck) with JSON tool schema
12. Connected agent to Gateway via MCP client (StreamableHTTP transport)
13. Configured CUSTOM_JWT authorizer on the runtime — rejects unauthenticated requests
14. Integrated Amazon Cognito as identity provider (OIDC discovery URL)
15. Modified agent to extract user identity from JWT claims (not self-reported headers)
16. Secured Gateway with same JWT authorizer — tool calls also require auth
17. Added `pyjwt` for token decoding
18. Gateway MCP client forwards `Authorization: Bearer` header for tool auth
19. Tested: unauthenticated requests rejected, authenticated requests succeed

### Phase 3: Observability & UI (Labs 5-6)
**Time: ~30 min**

20. Added Online Evaluation config (QualityMonitor) with three evaluators:
    - `Builtin.GoalSuccessRate` — did the agent solve the user's problem?
    - `Builtin.Correctness` — was the information accurate?
    - `Builtin.ToolSelectionAccuracy` — did it pick the right tool?
21. Set 100% sampling rate (workshop; production = 10-20%)
22. Built Flask web frontend that authenticates with Cognito on startup
23. Frontend injects JWT token into HTML page
24. Browser calls AgentCore REST API directly (streaming responses)
25. Each browser tab gets unique session ID (memory isolation)
26. Tested full flow: browser → JWT → AgentCore → agent → tools → streaming response

### Phase 4: Governance (Lab 7)
**Time: ~30 min**

27. Added ProcessRefund Lambda target to Gateway
28. Created Cedar Policy Engine in ENFORCE mode (default-deny)
29. Wrote four Cedar policies:
    - `refund_limit_policy` — permits refunds only when amount < $100
    - `warranty_check_policy` — permits all authenticated users
    - `refund_reason_policy` — forbids unless reason contains "defective"
    - `BlockSensitiveRefundReasons` — AI-powered guardrail detecting emails in input
30. Tested: $50 defective refund → allowed; $500 refund → denied; email in reason → denied
31. Verified policies enforce at Gateway boundary (no agent code changes needed)

### Phase 5: Declarative Agents (Lab 8)
**Time: ~45 min**

32. Created OrderResearchAgent using Harness (zero code — just JSON config)
33. Configured OAuth client_credentials for machine-to-machine Gateway auth
34. Stored credentials in AgentCore Token Vault
35. Connected Harness to same Gateway (same tools, same policies)
36. Added Code Interpreter tool (sandboxed code execution)
37. Added Human-in-the-Loop (HITL) inline function for manager approval
38. Tested HITL flow: agent pauses → human approves → agent resumes
39. Added xlsx skill from Anthropic's open skill library
40. Created PersistentReportAgent with session storage mount
41. Created ContainerAgent with custom Docker image (node:slim)

### Phase 6: Optimization (Lab 9)
**Time: ~45 min**

42. Generated system-prompt recommendation from real traces (`agentcore run recommendation`)
43. Generated tool-description recommendations (improved all 3 tools)
44. Created dedicated A/B runtime (CustomerSupportAB) with IAM auth
45. Wrote config-bundle-aware agent using `BeforeModelCallEvent` hook
46. Created two config bundles: control (current prompt) vs treatment (AI-recommended)
47. Created ABQualityMonitor eval config for the A/B runtime
48. Launched A/B test: 80% control / 20% treatment
49. Switched policy engine to LOG_ONLY for experimentation
50. Generated 30 test requests via load-gen script
51. Collected results: both variants scored 0.50 GoalSuccessRate (inconclusive due to sample size)
52. Documented the full optimization loop

---

## Interview Questions & Answers

### General Project Questions

**Q: Tell me about a project where you built an AI system end-to-end.**

> "I built a production-grade customer support agent on AWS using Amazon Bedrock AgentCore. It started as a simple prototype with local Python tools and evolved through 9 iterations into a fully secured, observable, governed system with A/B testing. The agent uses Claude Sonnet 4 via Bedrock, connects to external services through an API gateway, authenticates users via Cognito JWT tokens, enforces fine-grained Cedar policies, and continuously monitors quality using LLM-as-a-Judge evaluations. I also built a zero-code variant using AgentCore Harness for internal analysts, and ran a controlled A/B test comparing AI-optimized prompts against the baseline."

**Q: What was the most challenging part?**

> "The authentication architecture. The production agent uses CUSTOM_JWT auth (user tokens from Cognito), but the Gateway uses SigV4/IAM internally. When I needed to run an A/B test, the Gateway couldn't invoke the JWT-locked runtime. I had to design a separate IAM-authed runtime specifically for experimentation, while keeping the production runtime's security model intact. This taught me that security and experimentation can conflict, and you need deliberate architectural separation to handle both."

**Q: How did you ensure the system was production-ready?**

> "Five layers: (1) Authentication — JWT tokens from Cognito, no anonymous access. (2) Authorization — Cedar policies enforcing business rules (refund limits, required reasons) at the Gateway boundary. (3) Observability — OpenTelemetry auto-instrumentation feeding CloudWatch, plus online evaluations scoring every interaction. (4) Governance — AI-powered guardrails detecting sensitive data (email addresses) in tool inputs. (5) Optimization — trace-based recommendations validated via controlled A/B testing before promotion."

---

### Authentication & Security Questions

**Q: Explain the authentication flow in your system.**

> "Two flows: For end users — they authenticate via Cognito (username/password), receive a JWT access token, and include it as a Bearer token in API calls. AgentCore validates the token against Cognito's OIDC discovery endpoint, then my code decodes the JWT to extract the username claim for memory isolation. For machine-to-machine (the Harness agent) — it uses OAuth client_credentials grant. The Token Vault holds the client_id/secret, obtains a token from Cognito automatically, and the Harness forwards it to the Gateway. Both produce valid JWTs — just obtained differently."

**Q: What's the difference between authentication and authorization in your project?**

> "Authentication (Lab 4) answers 'who are you?' — Cognito issues JWT tokens that cryptographically prove identity. Authorization (Lab 7) answers 'what can you do?' — Cedar policies enforce business rules like refund limits. A user can be fully authenticated but still get denied if they try to process a $500 refund. The policies evaluate at the Gateway boundary — the Lambda function never even receives the denied request."

**Q: How does JWT work in your system?**

> "Cognito issues a signed JWT containing claims (username, expiry, client_id, scopes). The token is base64-encoded with three parts: header (algorithm), payload (claims), signature. AgentCore validates the signature against Cognito's public keys (fetched via OIDC discovery URL). My code then decodes the payload to extract the username — I use `options={'verify_signature': False}` because AgentCore already validated it at the infrastructure layer. The token expires after 1 hour, forcing re-authentication."

**Q: What is Cedar and why did you use it over IAM policies?**

> "Cedar is a purpose-built authorization language for application-level decisions. IAM controls 'can this role call this API?' (infrastructure level). Cedar controls 'can this user process a refund of $500 with reason X?' (business logic level). Cedar evaluates tool INPUT parameters — it sees the actual amount and reason fields before the Lambda executes. IAM can't do that. Cedar also supports AI-powered guardrails (detecting PII in inputs) which IAM doesn't offer."

---

### Architecture & Design Questions

**Q: Why did you use a Gateway instead of calling Lambda directly?**

> "Three reasons: (1) Decoupling — the agent discovers tools via MCP protocol; I can add/remove Lambda targets without redeploying agent code. (2) Policy enforcement — Cedar policies evaluate at the Gateway before requests reach Lambda; the Lambda stays simple. (3) Auth centralization — one JWT validation point instead of each Lambda validating tokens independently. It's the same pattern as API Gateway in microservices — a single entry point that handles cross-cutting concerns."

**Q: Explain MCP (Model Context Protocol) and why it matters.**

> "MCP is a standard protocol for connecting AI agents to tools. Instead of each agent framework inventing its own tool format, MCP provides a universal interface. My agent connects to the Gateway as an MCP client using StreamableHTTP transport — it discovers available tools automatically at connection time. If I add a new Lambda target to the Gateway tomorrow, the agent sees it immediately without code changes. It's like USB for AI tools — plug in anything that speaks the protocol."

**Q: Why two separate runtimes for A/B testing?**

> "Architecture constraint. The production runtime (CustomerSupport) uses CUSTOM_JWT auth — it requires a user token in every request. But the Gateway invokes A/B targets using SigV4/IAM (machine identity, no user token). These are incompatible — sending SigV4 to a JWT-locked runtime returns 'Authorization method mismatch.' Rather than weakening production security, I deployed a separate lightweight runtime (CustomerSupportAB) that accepts IAM auth. The Gateway can invoke it, while the end-user still authenticates to the Gateway with their JWT. Security stays intact; experimentation gets its own lane."

**Q: How would you scale this system?**

> "AgentCore handles scaling automatically — it's serverless. The Gateway distributes requests, Lambda functions scale independently, and Memory is a managed service. For the agent runtime, CodeZip packaging means AgentCore provisions compute on demand. In production, I'd: (1) reduce eval sampling to 10-20%, (2) add caching for repeated product lookups, (3) use connection pooling for MCP clients, (4) set up CloudWatch alarms on error rates and latency P99, and (5) implement circuit breakers if Lambda targets become unhealthy."

---

### Observability & Monitoring Questions

**Q: How do you monitor AI quality in production?**

> "Three layers: (1) OpenTelemetry auto-instrumentation captures every tool call, model invocation, latency, and error — sent to CloudWatch automatically via `aws-opentelemetry-distro` (no manual code). (2) Online Evaluations use LLM-as-a-Judge to score sessions on GoalSuccessRate, Correctness, and ToolSelectionAccuracy — like having a QA reviewer check every conversation. (3) A/B testing provides statistical validation before rolling out changes. The key insight: traces feed recommendations, recommendations feed A/B tests, A/B results feed promotion decisions — it's a closed feedback loop."

**Q: What's LLM-as-a-Judge?**

> "Instead of human reviewers reading every conversation, you use another LLM to evaluate agent performance. AgentCore's built-in evaluators analyze the full session trace (user intent, tool calls, final response) and score dimensions like 'did the agent achieve the user's goal?' This scales to thousands of sessions without human bottleneck. The trade-off: LLM judges can disagree with humans on edge cases, so you calibrate by spot-checking low-scoring sessions."

**Q: How does tracing work without adding code?**

> "The `aws-opentelemetry-distro` package in my dependencies auto-instruments Python at import time. It hooks into HTTP clients, the Strands SDK, and Bedrock API calls — capturing spans automatically. Each agent invocation generates a trace with spans for: session lookup, tool selection, model inference, tool execution, response generation. These are exported to CloudWatch via the OTLP protocol. I literally never wrote a single line of tracing code — it's all automatic."

---

### A/B Testing & Optimization Questions

**Q: How did you optimize agent performance?**

> "Data-driven, not intuition-driven. Step 1: Collect traces from real interactions (automatic via OpenTelemetry). Step 2: Run `agentcore run recommendation` which uses AI to analyze traces and suggest better prompts and tool descriptions. Step 3: Package the recommendation as a config bundle (immutable, versioned). Step 4: Run A/B test splitting traffic 80/20 between current and recommended. Step 5: Online eval scores both variants. Step 6: If statistically significant improvement (p < 0.05), promote the winner. The winner's traces become the baseline for the next cycle."

**Q: What were your A/B test results?**

> "Both variants scored 0.50 GoalSuccessRate with p-value of 1.0 — inconclusive. Control had 24 samples, treatment had 6 (due to the 80/20 split across 30 total requests). The confidence interval was [-0.45, +0.45] — extremely wide, meaning the true difference could be anywhere from 45% worse to 45% better. This was expected: with only 6 treatment samples, there wasn't enough statistical power to detect differences. In production you'd run thousands of sessions over days/weeks. The value was proving the infrastructure works end-to-end: Gateway correctly split traffic by session, config bundles were applied dynamically via the BeforeModelCallEvent hook, online eval scored both variants using LLM-as-a-Judge, and statistical analysis (two-sample t-test) was performed automatically."

**Q: What does p-value = 1.0 mean? Is that bad?**

> "It means there's zero evidence of a difference between control and treatment — they scored identically (both 0.50). p-value represents the probability that the observed difference happened by random chance. p=1.0 means '100% chance this is just noise.' You WANT p < 0.05 to declare a winner (less than 5% chance it's random), but you don't always get it — especially with small samples. It's not 'bad' — it's the correct statistical answer given the data. The system worked; we just needed more traffic."

**Q: What's a config bundle and why use it?**

> "A config bundle is a versioned, immutable snapshot of agent configuration — like a Docker image but for prompts and settings. The agent reads its active bundle at runtime via a `BeforeModelCallEvent` hook. This means I can swap prompts without redeploying code. For A/B testing, the Gateway assigns each session to a bundle version (control or treatment) and the agent dynamically applies it. It's the same concept as feature flags but specifically designed for LLM configuration."

---

### GenAI-Specific Questions

**Q: How do you prevent the agent from hallucinating?**

> "Multiple strategies: (1) System prompt explicitly says 'Always use tools to get accurate information rather than guessing.' (2) Tool descriptions are precise — after optimization, they specify exact valid values (e.g., 'product_category must be electronics, accessories, or audio'). (3) Tools return structured data — the agent relays facts, not generates them. (4) Online evaluations score Correctness — I can detect when the agent fabricates information. (5) Cedar policies prevent dangerous actions even if the model hallucinates tool parameters."

**Q: What's the difference between Strands SDK and just calling the Bedrock API?**

> "Raw Bedrock API gives you: send message, get response. One turn. Strands SDK gives you: agent loop (model decides which tool to call → calls it → feeds result back → decides next action), memory integration, streaming, session management, hooks (like BeforeModelCallEvent for A/B), and MCP client support. It's the difference between a raw HTTP library and a web framework — you could build everything yourself, but the SDK handles the orchestration loop."

**Q: When would you use a Harness vs writing code?**

> "Harness when: the agent is model + prompt + tools with no custom logic. Like an internal research bot or a report generator. Code when: you need custom orchestration (multi-agent coordination), custom auth flows (JWT extraction), complex memory strategies, or a user-facing UI. In my project, CustomerSupport needed code because of JWT-based identity extraction and per-user memory routing. OrderResearchAgent used Harness because it just needs a model, a prompt, and access to the same tools."

---

### Behavioral / Scenario Questions

**Q: A customer's refund request is being denied. How would you debug?**

> "I'd trace backward: (1) Check CloudWatch logs for the policy evaluation — which Cedar policy denied it? (2) Look at the tool input parameters the model constructed — was the amount correct? Was the reason field populated correctly? (3) Check if the denial was correct (policy working as designed) or a false positive (model constructed bad parameters). (4) If the model is constructing wrong parameters, that's a prompt/tool-description issue → feed into the recommendation system. (5) If the policy logic is wrong, update the Cedar statement and redeploy."

**Q: How would you add a new tool (e.g., order lookup) without downtime?**

> "One command: `agentcore add gateway-target --name OrderLookup --type lambda-function-arn --lambda-arn $ARN --tool-schema-file schema.json --gateway my-gateway-secure`. Then `agentcore deploy`. The agent discovers new tools via MCP on next connection — no code change, no restart. Add a Cedar policy if the tool needs restrictions. Total time: ~5 minutes. Zero downtime because AgentCore handles rolling deployment."

**Q: The agent's quality score drops from 80% to 50%. What do you do?**

> "(1) Check online eval dashboard — which evaluator dropped? GoalSuccessRate vs Correctness vs ToolSelectionAccuracy tells different stories. (2) Pull recent traces and look at low-scoring sessions — is it a specific tool failing? A new type of question the agent can't handle? (3) Check if a recent deployment changed anything (new policy blocking valid requests, tool schema mismatch). (4) If it's a prompt issue — run recommendation, get suggested fix, A/B test it. (5) If it's infrastructure — check Lambda health, Gateway latency, memory retrieval quality."

---

## Key Concepts to Explain Fluently

| Concept | 10-Second Explanation |
|---------|----------------------|
| AgentCore Runtime | Managed compute that hosts your agent — like ECS for AI agents |
| AgentCore Gateway | API Gateway specifically for AI tool routing + policy enforcement |
| AgentCore Memory | Managed vector store that gives agents long-term recall |
| AgentCore Harness | "Serverless agent" — just JSON config, no code to write or deploy |
| MCP | Universal protocol for connecting agents to tools (like USB for AI) |
| Cedar | Authorization language — evaluates tool inputs against business rules |
| Config Bundle | Versioned prompt/settings snapshot — swap without redeploying code |
| Online Eval | Automated quality scoring using LLM-as-a-Judge on live sessions |
| SEMANTIC strategy | Extracts and stores key facts from conversations for future recall |
| SUMMARIZATION strategy | Compresses long conversations into digestible summaries |
| OpenTelemetry | Industry-standard tracing/metrics framework — auto-instruments everything |
| CUSTOM_JWT | Auth mode where AgentCore validates JWT tokens from your identity provider |
| OAuth client_credentials | Machine-to-machine auth — no human involved, just service identity |
| SigV4 | AWS's request signing protocol — used internally between AWS services |
| BeforeModelCallEvent | Hook that fires before each model call — used to inject dynamic config |
| Human-in-the-Loop | Pattern where the agent pauses execution and waits for human approval |
| Default Deny | Security model where everything is blocked unless explicitly permitted |

---

## Numbers to Remember

| Metric | Value | Context |
|--------|-------|---------|
| Tools available | 5 | get_return_policy, get_product_info, check_warranty, process_refund, Exa AI web search |
| Cedar policies | 4 | refund limit, warranty permit, reason check, email guardrail |
| Evaluators | 3 | GoalSuccessRate, Correctness, ToolSelectionAccuracy |
| Runtimes | 2 | Production (JWT) + A/B (IAM) |
| Harnesses | 3 | OrderResearch, PersistentReport, Container |
| Config bundles | 2 | Control + Treatment |
| A/B split | 80/20 | Control 80%, Treatment 20% |
| Memory strategies | 2 | SEMANTIC + SUMMARIZATION |
| Auth methods used | 4 | JWT, OAuth, SigV4, IAM |
| Total test requests | 30 | Load-gen for A/B test |
| Deployment method | CDK | L3 constructs via `agentcore deploy` |

---

## What Makes This Project Stand Out (Interview Differentiators)

1. **Not just a chatbot** — full production system with security, governance, observability
2. **Multiple auth patterns** — JWT for users, OAuth for machines, IAM for internal services
3. **Policy-as-code** — Cedar policies enforce business rules without touching application code
4. **Data-driven optimization** — not guessing at prompts, using statistical validation
5. **Zero-code alternative** — demonstrated when to use Harness vs custom code (architectural judgment)
6. **Human-in-the-loop** — showed async approval workflows for high-risk actions
7. **AI guardrails** — semantic detection of PII in tool inputs (not just regex)
8. **Multi-agent architecture** — production agent + experimentation agent + declarative agents coexisting

---

## Common Follow-Up Questions

**"What would you do differently?"**
> Add a CI/CD pipeline (GitHub Actions → agentcore deploy), implement rate limiting per user, add a fallback model (switch to Nova if Bedrock throttles), and set up CloudWatch alarms that auto-rollback A/B tests if error rate spikes.

**"How does this compare to LangChain/LangGraph?"**
> Strands is AWS-native — tighter Bedrock integration, built-in memory/gateway/policy primitives. LangChain is framework-agnostic but requires more glue code for production concerns (auth, policies, managed deployment). Trade-off: vendor lock-in vs operational simplicity.

**"What's next?"**
> Multi-agent orchestration (CustomerSupport delegates to OrderResearch for complex cases), RAG integration for product manuals, and automated policy generation from compliance documents using Cedar's AI-assisted authoring.

**"Cost considerations?"**
> Per-invocation: Bedrock model cost (input/output tokens) + Lambda execution + Gateway request + Memory read/write. For optimization: recommendation runs + A/B eval sampling add ~20% overhead. Production optimization: reduce eval sampling to 10%, cache repeated tool lookups, batch memory writes.
