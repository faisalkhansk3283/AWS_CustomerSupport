# AWS Customer Support Agent - Workshop

## Architecture Overview

```
                    +---------------------------+
                    |   Amazon Bedrock AgentCore |
                    |       (Runtime Host)       |
                    +---------------------------+
                              |
                    +---------v---------+
                    |  CustomerSupport   |
                    |    Agent (Strands) |
                    +---------+---------+
                              |
         +--------------------+--------------------+
         |                    |                    |
   +-----v-----+      +------v------+      +-----v-----+
   |   Tools    |      |  MCP Client |      |  Memory   |
   | - Return   |      | (Exa AI    |      | (AgentCore|
   |   Policy   |      |  Web Search)|      |  Memory)  |
   | - Product  |      +-------------+      +-----------+
   |   Info     |
   +-----------+
         |
   +-----v-----+
   |   Model    |
   | (Bedrock   |
   |  Claude    |
   |  Sonnet 4) |
   +-----------+
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Strands Agents SDK (Python) |
| Model | Claude Sonnet 4 via Amazon Bedrock (`global.anthropic.claude-sonnet-4-6`) |
| Runtime | Amazon Bedrock AgentCore (CodeZip, Python 3.14) |
| Memory | AgentCore Memory (Semantic + Summarization strategies) |
| External Tools | Exa AI MCP Server (web search) |
| Infrastructure | AWS CDK (`@aws/agentcore-cdk` L3 constructs) |
| Build Type | CodeZip (Python source packaged as zip) |
| Network Mode | PUBLIC |
| Protocol | HTTP |

## Project Structure

```
CustomerSupport/
├── AGENTS.md                          # AI assistant context
├── README.md                          # AgentCore project docs
├── WORKSHOP.md                        # This file - lab documentation
├── agentcore/
│   ├── agentcore.json                 # Project config (agent, memory)
│   ├── aws-targets.json               # Deployment target (account/region)
│   ├── .env.local                     # Secrets (gitignored)
│   ├── .llm-context/                  # TypeScript type definitions
│   └── cdk/                           # CDK infrastructure
└── app/
    └── CustomerSupport/
        ├── main.py                    # Agent entrypoint + tools
        ├── model/
        │   ├── load.py                # Bedrock model config
        │   └── mantle_compat.py       # OpenAI model compatibility
        ├── mcp_client/
        │   └── client.py             # Exa AI MCP client
        ├── memory/
        │   └── session.py            # AgentCore Memory session manager
        └── skills/
            └── fetcher.py            # S3/Git skill fetcher utility
```

---

## Lab 1: Project Setup & Agent Creation

**Objective:** Initialize the AgentCore project and scaffold the base customer support agent.

**What we did:**
- Created a new AgentCore project using the CLI (`agentcore create`)
- Selected the Strands framework with Python runtime
- Configured the project structure separating infrastructure (`agentcore/`) from application code (`app/`)
- Set up AWS deployment targets (account + region) in `aws-targets.json`
- Configured CDK infrastructure using `@aws/agentcore-cdk` L3 constructs

**Key files created:**
| File | Purpose |
|------|---------|
| `agentcore/agentcore.json` | Main project configuration (agents, memories, gateways) |
| `agentcore/aws-targets.json` | AWS account and region for deployment |
| `agentcore/cdk/` | CDK infrastructure project |
| `app/CustomerSupport/main.py` | Agent application entrypoint |
| `app/CustomerSupport/pyproject.toml` | Python dependencies |

**Commands used:**
```bash
agentcore create
agentcore dev        # Run locally with hot-reload
agentcore validate   # Verify configuration
```

---

## Lab 2: Integrating Memory with Session & User Identity

**Objective:** Wire up AgentCore Memory so the agent can remember context across sessions per user.

**What we did:**
- Imported the memory session manager into the main agent module
- Added `requestHeaderAllowlist` in `agentcore.json` to pass the custom user ID header (`X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id`) to the agent at runtime
- Modified `get_or_create_agent()` to accept `session_id` and `user_id` parameters
- Updated the invoke entrypoint to extract `session_id` from context and `user_id` from request headers
- Added validation to ensure both `session_id` and `user_id` are present before invoking the agent
- Extracted the system prompt to a module-level constant for cleaner code organization
- Passed the `session_manager` (from `memory/session.py`) into the Strands `Agent` constructor

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `requestHeaderAllowlist` with custom user ID header |
| `app/CustomerSupport/main.py` | Integrated memory session manager, user/session extraction from context |

**How it works:**
1. The caller passes `--session-id` and `--user-id` when invoking the agent
2. The custom user ID header is allowlisted so AgentCore Runtime forwards it to the app
3. The memory session manager is initialized with the session/user IDs
4. Memory strategies (SEMANTIC + SUMMARIZATION) store and retrieve per-user facts and conversation summaries
5. The agent now remembers previous interactions and personalizes responses

**Commands used:**
```bash
agentcore invoke --prompt "What headphones do you have?" --session-id my-session --user-id user123
```

---

## Lab 3: AgentCore Gateway — Connecting to AWS Lambda Tools

**Objective:** Connect the agent to an external AWS Lambda function via AgentCore Gateway, so the agent can call services it doesn't own.

**Why this matters:**

Before this lab, all tools were Python functions hardcoded in `main.py`. That works for simple cases, but in the real world:
- Tool logic may live in separate services (maintained by other teams)
- Tools may be written in different languages
- You want to add/remove tools without redeploying the agent

AgentCore Gateway solves this by acting as a **bridge** — it exposes external services (like AWS Lambda functions) as MCP tools that the agent automatically discovers and calls.

```
Before Lab 3:
  Agent → Python functions only (get_return_policy, get_product_info)

After Lab 3:
  Agent → Python functions (get_return_policy, get_product_info)
       → Gateway → AWS Lambda function (check_warranty)
```

> **Note:** "Lambda" here refers to **AWS Lambda** (a serverless compute service that runs your code in the cloud), NOT Python's `lambda x: x+1` syntax.

**What we did:**
- Created an AgentCore Gateway (`my-gateway`) in `agentcore.json`
- Added a Lambda target (`WarrantyCheck`) pointing to a pre-deployed AWS Lambda function
- Defined the tool schema in `warranty_schema.json` so the agent knows how to call it
- Created `get_gateway_mcp_client()` in `mcp_client/client.py` to connect to the gateway
- Added the gateway MCP client to the agent's tool list
- Removed `warranty_months` from the local product catalog (warranty is now handled by the Lambda)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `agentCoreGateways` with Lambda target |
| `app/CustomerSupport/tool/warranty_schema.json` | NEW — Tool schema for `check_warranty` |
| `app/CustomerSupport/mcp_client/client.py` | Added `get_gateway_mcp_client()` |
| `app/CustomerSupport/main.py` | Imported gateway client, removed warranty_months from products |

**How it works:**
1. AgentCore deploys the Gateway and sets `AGENTCORE_GATEWAY_MY_GATEWAY_URL` env var at runtime
2. The agent connects to the gateway as an MCP client
3. The gateway exposes `check_warranty` as a discoverable tool (defined by the JSON schema)
4. When a customer asks about warranty, the agent calls `check_warranty` → Gateway → AWS Lambda
5. The Lambda function returns warranty status, and the agent relays it to the customer

**Commands used:**
```bash
agentcore add gateway
agentcore deploy
agentcore invoke --prompt "Is my Smart Watch still under warranty?" --session-id s1 --user-id user123
```

---

## Lab 4: Securing the Agent with JWT Authentication (Amazon Cognito)

**Objective:** Lock down the agent so only authenticated users can access it, and user identity is cryptographically verified (not self-reported).

**What was lacking before:**

In Labs 1-3, anyone could call the agent and claim to be any user by simply passing a header:
```bash
# Anyone could pretend to be Sarah — no verification!
-H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah"
```
This is insecure — a malicious caller could access another user's memories, warranty info, or personal data.

**What Lab 4 adds:**

```
Before Lab 4 (insecure):
  Client → "I'm Sarah" (self-reported header) → Agent trusts blindly

After Lab 4 (secure):
  Client → authenticates with Cognito → receives JWT token
        → sends token to Agent → Agent verifies token → extracts real username from claims
```

**Think of it like this:** Before, you could walk into a bank and say "I'm John, show me his account." Now you need to show a government-issued ID (the JWT token) that the bank (AgentCore) validates against the issuer (Cognito).

**What we did:**
- Added `CUSTOM_JWT` authorizer to the agent runtime — AgentCore now rejects requests without a valid token
- Configured Cognito as the identity provider (discovery URL + allowed client IDs)
- Secured the Gateway with the same JWT authorizer — Lambda tools also require auth
- Modified `main.py` to extract `user_id` from JWT claims (`username` field) instead of a custom header
- Gateway MCP client now forwards the `Authorization` header so tool calls are also authenticated
- Added `pyjwt` dependency for token decoding
- Downgraded runtime to Python 3.13 (compatibility)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added JWT authorizer to runtime + gateway, Cognito config |
| `app/CustomerSupport/main.py` | JWT-based user extraction, auth header forwarding |
| `app/CustomerSupport/mcp_client/client.py` | Gateway client passes Authorization header |
| `app/CustomerSupport/pyproject.toml` | Added `pyjwt` dependency |

**How it works:**
1. User authenticates with Amazon Cognito and receives a JWT access token
2. Client sends request with `Authorization: Bearer <token>` header
3. AgentCore Runtime validates the token against Cognito's OIDC discovery endpoint
4. Agent code decodes the JWT and extracts the `username` claim as `user_id`
5. Memory and tools now operate on a verified identity — no spoofing possible
6. Gateway also validates the token before allowing Lambda tool calls

**Commands used:**
```bash
# Get a token from Cognito first, then invoke with it:
agentcore invoke "What's my warranty status?" \
  --session-id $SESSION_ID \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --stream
```

---

## Lab 5: Evaluating Agent Quality with Online Evaluations

**Objective:** Set up continuous quality monitoring so every agent interaction is automatically scored.

**What was lacking before:**

In Labs 1-4, the agent was deployed and secured — but you had no way to know if it was giving **good** answers. Was it picking the right tools? Were customers getting their problems solved? You'd have to manually read every conversation to find out.

**What Lab 5 adds:**

AgentCore Evaluations automatically scores your agent's interactions using LLM-as-a-Judge. It samples live sessions and rates them — no manual review needed.

```
Before Lab 5:
  Customer asks question → Agent answers → ??? (hope it was good)

After Lab 5:
  Customer asks question → Agent answers → Evaluators automatically score:
    - GoalSuccessRate: Did the agent solve the customer's problem?
    - Correctness: Was the information accurate?
    - ToolSelectionAccuracy: Did it pick the right tools?
```

**What we did:**
- Added an online evaluation config (`QualityMonitor`) that monitors the CustomerSupport agent
- Configured three built-in evaluators (GoalSuccessRate, Correctness, ToolSelectionAccuracy)
- Set sampling rate to 100% (every interaction evaluated; production would use 10-20%)
- Enabled evaluation immediately on deployment (`enableOnCreate: true`)
- Deployed and generated test interactions with varied queries (product info, return policy, warranty, multi-tool)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `onlineEvalConfigs` with QualityMonitor |

**Score interpretation:**
| Score | Meaning | Action |
|-------|---------|--------|
| 80-100% | Excellent | Monitor and maintain |
| 60-80% | Good but improvable | Review low-scoring sessions |
| Below 60% | Needs attention | Investigate root causes |

**Commands used:**
```bash
# Add online eval config
agentcore add online-eval \
  --name QualityMonitor \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy \
  --sampling-rate 100 \
  --enable-on-create

# Deploy
agentcore deploy -y -v

# Run on-demand evaluation
agentcore run eval \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness \
  --days 1
```

---

## Lab 6: Web Chat Frontend (Flask)

**Objective:** Build a web chat interface so users can interact with the agent through a browser instead of the terminal.

**What was lacking before:**

In Labs 1-5, the only way to talk to the agent was via `agentcore invoke` in the terminal with a bearer token. Real customers need a proper chat UI.

**What Lab 6 adds:**

```
Before Lab 6:
  Terminal → agentcore invoke --bearer-token ... → Agent

After Lab 6:
  Browser → Flask server (authenticates with Cognito on startup)
         → Serves HTML page with token + runtime ARN injected
         → Browser calls AgentCore REST API directly
         → Streaming response displayed in chat UI
```

**How it works:**
1. Flask server starts and authenticates with Cognito (same `USER_PASSWORD_AUTH` flow from Lab 4)
2. User opens the page — Flask injects the access token and runtime ARN into the HTML
3. User types a message in the chat
4. Browser calls the AgentCore REST API directly with `Authorization: Bearer` header
5. AgentCore validates the JWT, processes the request through the agent
6. Streaming response is displayed in the chat bubble

**What we created:**
| File | Purpose |
|------|---------|
| `app/CustomerSupport/frontend/__init__.py` | Package marker |
| `app/CustomerSupport/frontend/frontend.py` | Flask server — Cognito auth, serves chat page |
| `app/CustomerSupport/frontend/templates/index.html` | Chat UI — calls AgentCore API directly from browser |

**Key design decisions:**
- **Why not boto3?** boto3's `invoke_agent_runtime` uses IAM (SigV4) auth. Our runtime uses Custom JWT auth, so we call the REST API directly with a Bearer token.
- **Why Flask and not just a static page?** Flask handles Cognito authentication server-side on startup and injects the token into the page. The browser never sees credentials.
- **Session management:** Each browser tab gets a unique `sessionId` (UUID). Clicking "New Session" generates a fresh one, resetting conversation context.

**Dependencies added:** `flask`, `boto3`, `requests`

**Commands used:**
```bash
# Install dependencies
cd app/CustomerSupport
uv add flask boto3 requests

# Create frontend structure
mkdir -p app/CustomerSupport/frontend/templates

# Run the frontend
cd app/CustomerSupport/frontend
uv run python frontend.py
# Opens on http://localhost:8501
```

**Testing the UI:**
| Action | What it tests |
|--------|--------------|
| "What products do you have?" | Product lookup (local tool) |
| "What's the return policy for electronics?" | Return policy (local tool) |
| "Check warranty for PROD-002" | Warranty check (Gateway → Lambda) |
| "Do you remember me?" | Long-term memory recall |
| Send "My name is Alex" then "What's my name?" | Session persistence |
| Click New Session → "What's my name?" | Session isolation (won't remember) |

---

## Lab 7: Governing Agent Actions with Cedar Policies

**Objective:** Add fine-grained authorization rules so the agent can't perform unrestricted actions — even if a user asks it to.

**What was lacking before:**

In Labs 1-6, authentication answered "who is calling?" but NOT "what are they allowed to do?" Any authenticated user could call any tool with any parameters. If a refund tool existed, a user could request a $10,000 refund and the agent would happily process it.

**What Lab 7 adds:**

```
Before Lab 7:
  Authenticated user → Agent → calls any tool with any parameters → no limits

After Lab 7:
  Authenticated user → Agent → calls tool → Gateway checks Cedar policy:
    - Is the refund amount < $100? → Allow
    - Is the refund amount >= $100? → DENY (before it reaches the Lambda)
    - Does the reason contain "defective"? → Allow
    - Reason doesn't mention "defective"? → DENY
```

**Think of it like this:** Authentication is the ID check at the door. Policies are the spending limits on your credit card — even though you're verified, you can't charge $1 million.

**Key concepts:**
| Concept | What it means |
|---------|--------------|
| Policy Engine | Container that holds and evaluates Cedar policies |
| Cedar Policy | A rule: permit or forbid a tool call based on conditions |
| ENFORCE mode | Denied requests are blocked at the Gateway |
| Default Deny | Everything is denied unless explicitly permitted |

**What we did:**
1. Added a `process_refund` Lambda tool to the gateway (with tool schema)
2. Created a Policy Engine (`CustomerSupportPolicyEngine`) attached to the gateway in ENFORCE mode
3. Created three Cedar policies:
   - `refund_limit_policy` — Permits refunds only when amount < $100
   - `warranty_check_policy` — Permits warranty checks for all authenticated users
   - `refund_reason_policy` — Forbids refunds unless reason contains "defective"

**Key changes:**
| File | Change |
|------|--------|
| `app/CustomerSupport/tool/refund_schema.json` | NEW — Tool schema for `process_refund` |
| `agentcore/agentcore.json` | Added refund gateway target, policy engine, and 3 Cedar policies |

**Why the warranty policy is needed:**
Cedar uses **default deny**. Once you attach a Policy Engine in ENFORCE mode, every tool needs an explicit `permit` policy. Without one, the warranty tool (which worked fine before) would start failing.

**How policies enforce without changing agent code:**
- Policies evaluate at the **Gateway boundary** — before the request reaches the Lambda
- The agent code never changed
- The Lambda function never changed
- If the policy denies, the agent simply gets an error back and tells the user it can't do that

**Test results:**
| Prompt | Result | Why |
|--------|--------|-----|
| "Refund $50 for ORD-12345, item was defective" | Allowed | amount < 100 AND reason contains "defective" |
| "Refund $500 for ORD-67890, full refund" | Denied | amount >= 100 |
| "Refund $50 for ORD-11111, changed my mind" | Denied | reason doesn't contain "defective" |
| "Check warranty for PROD-002" | Allowed | explicit permit for all users |

**Commands used:**
```bash
# Add refund tool to gateway
agentcore add gateway-target \
  --type lambda-function-arn \
  --name ProcessRefund \
  --lambda-arn $REFUND_LAMBDA_ARN \
  --tool-schema-file app/CustomerSupport/tool/refund_schema.json \
  --gateway my-gateway-secure

# Create policy engine
agentcore add policy-engine \
  --name CustomerSupportPolicyEngine \
  --attach-to-gateways my-gateway-secure \
  --attach-mode ENFORCE

# Add policies
agentcore add policy --name refund_limit_policy --engine CustomerSupportPolicyEngine \
  --statement "permit(...) when { context.input.amount < 100 };"

agentcore add policy --name warranty_check_policy --engine CustomerSupportPolicyEngine \
  --statement "permit(...) when { principal is AgentCore::OAuthUser };"

agentcore add policy --name refund_reason_policy --engine CustomerSupportPolicyEngine \
  --statement "forbid(...) unless { ((context.input).reason) like \"*defective*\" };"

# Deploy
agentcore deploy -y -v
```

---

## Lab 7 Bonus: Semantic Guardrails — Blocking Sensitive Information

**Objective:** Add a semantic guardrail that detects and blocks email addresses in refund tool inputs, without changing any agent or Lambda code.

**What this adds on top of Lab 7:**

Lab 7's policies are **deterministic** — they check exact values (amount < 100, reason contains "defective"). This bonus adds a **semantic** policy that uses AI to detect sensitive information (like email addresses) in the tool's input before it reaches the Lambda.

```
Customer message: "Refund $50 for ORD-123, the defective item had wrong email alice@example.com"
    ↓
Agent constructs tool call: reason="...alice@example.com..."
    ↓
Gateway evaluates policies:
    ├─ refund_limit_policy: amount=50 < 100 ✅
    ├─ refund_reason_policy: contains "defective" ✅
    └─ BlockSensitiveRefundReasons: EMAIL detected in reason ❌ DENIED
```

**Key distinction:** This is a **tool-input guardrail**, not a user-message filter. The model sees the customer's message first and constructs tool arguments — the guardrail then evaluates what the model puts in `context.input.reason`.

**What we did:**
- Added `BlockSensitiveRefundReasons` policy using `BedrockGuardrails::SensitiveInformation`
- Configured it to detect EMAIL entities with confidence threshold ≥ 0.2
- Policy enforces at the Gateway boundary before Lambda execution

**Key change:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `BlockSensitiveRefundReasons` semantic guardrail policy |

**Possible outcomes when email is in the prompt:**
1. **Model includes email in reason** → Guardrail detects it → Denies → Model may retry without the address
2. **Model generalizes the reason** (removes email itself) → Guardrail doesn't trigger → Refund succeeds

Both outcomes are valid — the guardrail is a safety net, not the only defense.

**Commands used:**
```bash
agentcore add policy \
  --name BlockSensitiveRefundReasons \
  --engine CustomerSupportPolicyEngine \
  --statement "forbid(...) when guardrails { BedrockGuardrails::SensitiveInformation([\"EMAIL\"], [context.input.reason]).maxConfidenceScore().greaterThanOrEqual(decimal(\"0.2\")) };" \
  --validation-mode IGNORE_ALL_FINDINGS \
  --enforcement-mode ACTIVE

agentcore deploy -y -v
```

---

## Lab 8: Zero-Code Agents with AgentCore Harness

**Objective:** Create a fully functional agent using only CLI configuration — no Python code, no dependencies, no build step.

### How Harness Relates to CustomerSupport (Key Clarification)

**The Harness (OrderResearchAgent) is a completely SEPARATE agent from CustomerSupport. They are siblings, NOT parent-child.**

```
                     ┌─────────────────────────────┐
                     │       AgentCore Gateway       │
                     │      (my-gateway-secure)      │
                     │                               │
                     │  Tools:                       │
                     │  ├─ check_warranty (Lambda)   │
                     │  └─ process_refund (Lambda)   │
                     │                               │
                     │  Policies (Cedar):            │
                     │  ├─ refund_limit < $100       │
                     │  ├─ reason must be "defective"│
                     │  └─ block emails in reason    │
                     └──────────────┬────────────────┘
                                    │
                     ┌──────────────┼──────────────┐
                     │              │              │
          ┌──────────▼───┐   ┌─────▼──────────────▼┐
          │ CustomerSupport│   │ OrderResearchAgent   │
          │ (Runtime Agent)│   │ (Harness Agent)      │
          │                │   │                      │
          │ • Python code  │   │ • ZERO code          │
          │ • main.py      │   │ • Just harness.json  │
          │ • Local tools  │   │ • Code Interpreter   │
          │ • MCP client   │   │ • Shell access       │
          │ • Memory module│   │ • Inline functions   │
          │ • JWT auth     │   │ • OAuth M2M auth     │
          │ (user token)   │   │ (machine token)      │
          └────────────────┘   └──────────────────────┘
```

**Common questions answered:**

| Question | Answer |
|----------|--------|
| If CustomerSupport is offline, does Harness break? | **No.** They are independent. Harness talks to the Gateway directly. |
| Do they share the same Lambda tools? | **Yes.** Both connect to the same Gateway, so both can call `check_warranty` and `process_refund`. |
| Do the same policies apply to both? | **Yes.** Policies are on the Gateway — they don't care which agent is calling. |
| How does Harness authenticate to the Gateway? | **OAuth client_credentials** (machine-to-machine). CustomerSupport forwards the user's JWT. Different auth methods, same Gateway. |
| Why use Harness instead of writing code? | When you don't need custom orchestration — just model + prompt + tools. Faster to deploy, no dependencies to manage. |
| Does Harness have a UI? | **No.** It's CLI/API only — meant for internal analysts, not end customers. |
| Does Harness have per-user memory? | **No** (disabled by default). It uses a single app identity, not individual user tokens. |

### Understanding Authentication: How Both Agents Get Tokens

**The Gateway requires a JWT token from anyone calling it.** The two agents get tokens differently:

```
┌──────────────────────────────────────────────────────────────────────┐
│                        COGNITO (Token Factory)                         │
│                                                                        │
│  Has two types of "accounts":                                         │
│                                                                        │
│  1. USER ACCOUNT (for humans)        2. APP CLIENT (for software)     │
│     username: workshopuser@...          client_id: 1aqba7n68h...      │
│     password: WorkshopPass1!            client_secret: xyz789...      │
│     → Used by Flask/browser             → Used by Harness             │
│                                                                        │
│  Both produce a valid JWT token — just obtained differently            │
└────────────────────┬───────────────────────────┬──────────────────────┘
                     │                           │
                     ▼                           ▼
        ┌────────────────────┐       ┌────────────────────┐
        │  CustomerSupport    │       │  Harness            │
        │                    │       │                    │
        │  Human types       │       │  Code sends        │
        │  username+password │       │  client_id+secret  │
        │  → gets JWT        │       │  → gets JWT        │
        │  → forwards to GW  │       │  → forwards to GW  │
        └────────────────────┘       └────────────────────┘
```

**Analogy:** Cognito is a building security desk:
- Employees badge in with name + photo (username/password) → get a visitor pass (JWT)
- The cleaning robot has a special access code (client_id/secret) → also gets a pass (JWT)
- Both passes open the same doors (Gateway) — they're just issued to different entities

### Where Do the Credentials Come From?

The workshop organizers pre-created everything in Cognito before Lab 1. They stored the values in **SSM Parameter Store** (a key-value config store in AWS):

```
/app/customersupport/agentcore/client_id          → machine app client_id (for Harness)
/app/customersupport/agentcore/web_client_id      → web app client_id (for Flask/humans)
/app/customersupport/agentcore/pool_id            → Cognito User Pool ID
/app/customersupport/agentcore/cognito_auth_scope → what permissions the token grants
/app/customersupport/agentcore/cognito_discovery_url → where to validate tokens
```

In Lab 8, you just READ these values with `aws ssm get-parameter` and passed them to `agentcore add credential`. You didn't create the Cognito setup — you just used what was already there.

### The Full Token Flow for Harness (Step by Step)

```
1. You run: agentcore invoke --harness OrderResearchAgent "Check warranty for PROD-001"

2. Harness needs to call the Gateway → needs a token

3. Harness asks AgentCore Token Vault: "Get me a token using gateway-egress-oauth"

4. Token Vault calls Cognito:
   POST /oauth2/token
   Body: grant_type=client_credentials, client_id=1aqba..., client_secret=xyz...

5. Cognito checks: "Is this client_id + secret valid?" → Yes
   Cognito returns: { "access_token": "eyJhbG...", "expires_in": 3600 }

6. Harness calls Gateway: "Authorization: Bearer eyJhbG..."

7. Gateway validates: "Was this JWT signed by my trusted Cognito?" → Yes ✅
   Gateway checks Cedar policies → Allowed ✅
   Gateway calls Lambda → returns warranty info

8. Harness returns result to you in the terminal
```

### What we did:

1. **Created the Harness** — Declared an agent with model, system prompt, and code interpreter tool (one CLI command)
2. **Connected to existing Gateway** — Reused the same secured Gateway from Labs 3-7 with OAuth outbound auth
3. **Created OAuth credential** — Machine-to-machine auth so the Harness can call the JWT-protected Gateway
4. **Deployed** — Single command, no build step needed
5. **Tested Gateway tools** — Warranty checks and policy-blocked refunds worked identically to CustomerSupport
6. **Used Shell access** — Ran commands inside the Harness microVM (`--exec`)
7. **Tested filesystem persistence** — Files created in one invocation persist across the session
8. **Overrode model per invocation** — Switched to Nova Lite without redeploying
9. **Verified policy enforcement** — $500 refund denied (same policies apply)
10. **Added Human-in-the-Loop** — Inline function that pauses the agent for manager approval, then resumes

**Key files created:**
| File | Purpose |
|------|---------|
| `app/OrderResearchAgent/harness.json` | Declarative agent config (model, tools, prompt) |
| `app/OrderResearchAgent/system-prompt.md` | System prompt for the agent |
| `app/OrderResearchAgent/test_hitl.py` | Python script testing Human-in-the-Loop flow |

**Human-in-the-Loop (HITL) flow:**
```
1. User asks for $200 refund
2. Agent tries process_refund → Gateway policy blocks it (>$100)
3. Agent calls approve_exception (inline function) → Harness PAUSES
4. Script detects pause, prompts human: "Approve? (yes/no)"
5. Human types "yes"
6. Script sends approval back → Harness RESUMES
7. Agent reports: "Approved by Manager Jane"
```

**Commands used:**
```bash
# Create harness (zero code!)
agentcore add harness \
  --name OrderResearchAgent \
  --model-provider bedrock \
  --model-id us.anthropic.claude-sonnet-4-6 \
  --system-prompt "You are an order research specialist..." \
  --tools agentcore_code_interpreter

# Connect to existing secured gateway
agentcore add credential --type oauth --name gateway-egress-oauth ...
agentcore add tool --harness OrderResearchAgent --type agentcore_gateway \
  --name my-gateway-secure --gateway-arn "$GATEWAY_ARN" \
  --outbound-auth oauth --grant-type CLIENT_CREDENTIALS

# Add human-in-the-loop tool
agentcore add tool --harness OrderResearchAgent --type inline_function \
  --name approve_exception \
  --description "Request manager approval for refunds exceeding automated limit"

# Deploy and test
agentcore deploy -y -v
agentcore invoke --harness OrderResearchAgent --session-id "$SESSION" "..."
```

### Lab 8 Bonus: Advanced Harness Features

**What we explored:**

#### 1. Agent Skills (xlsx)
Added a markdown-based skill bundle from Anthropic's open library that teaches the agent how to create professional Excel reports. Skills are domain-specific instructions the model loads automatically — no fine-tuning needed.

```bash
agentcore add skill --harness OrderResearchAgent \
  --git https://github.com/anthropics/skills \
  --git-path skills/xlsx
```

**Result:** The agent created a formatted `.xlsx` file with color-coded warranty statuses, frozen headers, and a summary section.

#### 2. Session Storage Mount (PersistentReportAgent)
Files normally disappear when a session ends. `--session-storage` mounts a persistent path so reports survive across stop/resume cycles.

```bash
agentcore add harness --name PersistentReportAgent \
  --session-storage /mnt/reports/ ...
```

#### 3. Custom Container (ContainerAgent)
Provides a pre-configured environment (installed tools like git, node, terraform) without replacing the agent's brain. The container is the "laptop" the agent uses, not the agent itself.

```bash
agentcore add harness --name ContainerAgent \
  --container public.ecr.aws/docker/library/node:slim ...
```

**Why separate harnesses for each bonus?**
Harnesses are **immutable once created** — there's no `agentcore update harness`. To change fundamental config (storage mounts, container image), you create a new one. That's a design choice: each harness is a versioned, reproducible agent definition.

### What is a "Harness" as a Concept?

A Harness is a **standardized, declarative agent format** — an AgentCore resource type (like `runtime`, `memory`, `gateway`). It has:
- Its own ARN (e.g., `arn:aws:bedrock-agentcore:...:harness/OrderResearchAgent-...`)
- Version numbers (incremented on each deploy)
- A fixed schema: model + prompt + tools + skills + memory + container + storage

```
Building an agent FROM CODE (Runtime):       Building an agent FROM CONFIG (Harness):
  - Write main.py                              - Write harness.json
  - Manage dependencies (pyproject.toml)       - No dependencies
  - Handle orchestration yourself              - AgentCore handles orchestration
  - Full flexibility                           - Standardized but limited
  - Like building a car from parts             - Like ordering a car from a menu
```

**When to use which:**
| Use Runtime (code) when... | Use Harness (config) when... |
|---|---|
| You need custom orchestration | Model + prompt + tools is enough |
| You need custom memory logic | Default memory behavior works |
| You need complex tool chaining | Tools are independent |
| You're building for end-users with a UI | You're building for internal/CLI use |

---

## Lab 9: Data-Driven Optimization — Recommendations & A/B Testing

**Objective:** Use real agent traces to generate AI-optimized prompts and tool descriptions, then validate improvements with a controlled A/B test on live traffic.

### What was lacking before:

In Labs 1-8, you built a working agent with tools, memory, auth, policies, monitoring, UI, and harnesses. But how do you know the system prompt is optimal? How do you know the tool descriptions help the model pick the right tool? You don't — you're guessing.

**Lab 9 closes the loop:** traces → analysis → recommendations → A/B test → promote winner → repeat.

```
Before Lab 9:
  You write prompts → deploy → hope they're good → never validate

After Lab 9:
  Agent runs → traces collected automatically (OpenTelemetry)
  → AI coach analyzes traces → recommends better prompts/tool descriptions
  → Package as config bundles (control vs treatment)
  → A/B test splits live traffic 80/20
  → Online eval scores both variants
  → Statistical significance → promote winner
  → Winner's traces become baseline for next round
```

### How Traces Get Collected (No Extra Code Needed)

```
pyproject.toml includes:
  "aws-opentelemetry-distro"      ← auto-instruments every agent call

Agent runs → OpenTelemetry captures:
  • Which tools were called and in what order
  • What the model received (system prompt, user message)
  • What the model responded
  • How long each step took
  • Whether the user's goal was achieved (from online eval)

These traces are stored in AgentCore and queryable via CLI.
```

**You never added tracing code to main.py.** The `aws-opentelemetry-distro` dependency auto-instruments everything at startup. The `agentcore run recommendation` command reads these stored traces.

### Step 1: Generate Recommendations from Traces

The optimizer reads your agent's real interaction traces and identifies improvements:

```bash
# System prompt recommendation
agentcore run recommendation \
  --type system-prompt \
  --runtime CustomerSupport \
  --name cs-prompt-rec \
  --days 1

# Tool description recommendation
agentcore run recommendation \
  --type tool-description \
  --runtime CustomerSupport \
  --name cs-tool-rec \
  --days 1
```

**What the optimizer found:**

| Recommendation Type | What it analyzed | What it improved |
|---|---|---|
| System Prompt | Agent behavior across all sessions | Added structured response format, explicit tool-usage rules, professional tone guidance |
| Tool: `get_return_policy` | Agent sometimes guessed category instead of looking up product first | Added: "valid values are electronics/accessories/audio" + "derive category from product info, don't guess" |
| Tool: `get_product_info` | Agent uses both IDs and names, often in parallel with warranty | Added: exact response fields listed, parallel-call hint |
| Tool: `check_warranty` | 100% success rate, always PROD-XXX format | Added: exact response format (status, expiry date), parallel-call guidance |

**Why better descriptions matter:** The model reads tool descriptions to decide WHICH tool to call and HOW. Vague descriptions = wrong tool choices. Precise descriptions = fewer mistakes, better scores.

### Step 2: Create a Dedicated A/B Runtime (CustomerSupportAB)

**Why a separate runtime?**

Your `CustomerSupport` runtime uses `CUSTOM_JWT` auth (Lab 4). The Gateway invokes A/B targets using SigV4/IAM auth. These are incompatible — the Gateway's SigV4 call would get rejected with "Authorization method mismatch."

Solution: Deploy a lightweight A/B-specific runtime that keeps the default IAM authorizer:

```
Client (Cognito JWT) → Gateway ──┬── Bundle v1 (control)   ──(SigV4)──→ CustomerSupportAB Runtime
                                 └── Bundle v2 (treatment) ──(SigV4)──→ CustomerSupportAB Runtime
```

**Security note:** CustomerSupportAB is NOT unauthenticated — it uses IAM auth, so only the Gateway's execution role can invoke it. It's a scoped, disposable runtime for experimentation.

```bash
agentcore add agent \
  --name CustomerSupportAB \
  --language Python \
  --framework Strands \
  --model-provider Bedrock \
  --memory none \
  --build CodeZip
```

**Key file created:**
| File | Purpose |
|------|---------|
| `app/CustomerSupportAB/main.py` | Config-bundle-aware agent — reads system prompt from active bundle at runtime via `BeforeModelCallEvent` hook |

**How the AB agent differs from CustomerSupport:**
| Feature | CustomerSupport | CustomerSupportAB |
|---------|----------------|-------------------|
| Auth | CUSTOM_JWT (user tokens) | IAM (Gateway only) |
| Memory | SharedMemory (per-user) | None (stateless) |
| System prompt | Hardcoded in main.py | Read from config bundle dynamically |
| Purpose | Production agent for customers | Experimentation runtime for A/B tests |
| Gateway client | Forwards user JWT | Not needed (Gateway calls IT) |

### Step 3: Configuration Bundles

A **config bundle** is a versioned, immutable snapshot of agent configuration that can be swapped at runtime without redeploying code. The agent reads its active bundle on each invocation.

```bash
# Control — current prompt (baseline)
agentcore add config-bundle \
  --name customerSupportControl \
  --commit-message "Baseline prompt" \
  --components '{"{{runtime:CustomerSupportAB}}": {"configuration": {"system_prompt": "..."}}}'

# Treatment — AI-recommended prompt
agentcore add config-bundle \
  --name customerSupportTreatment \
  --commit-message "Recommended prompt from cs-prompt-rec" \
  --components "$(jq -n --arg prompt "$RECOMMENDED_PROMPT" '...')"
```

**Think of it like this:**
- Config bundle = a "settings preset" for the agent
- Control = your current settings
- Treatment = the new settings you want to test
- The agent code stays identical — only the config it reads changes

### Step 4: Online Eval for A/B Runtime

The `QualityMonitor` from Lab 5 is bound to the CustomerSupport runtime's log group — it won't score CustomerSupportAB sessions. Created a dedicated eval:

```bash
agentcore add online-eval \
  --name ABQualityMonitor \
  --runtime CustomerSupportAB \
  --evaluator Builtin.GoalSuccessRate \
  --sampling-rate 100 \
  --enable-on-create
```

### Step 5: Launch the A/B Test

```bash
agentcore run ab-test \
  --mode config-bundle \
  --name cs_prompt_abtest \
  --gateway my-gateway-secure \
  --runtime CustomerSupportAB \
  --control-bundle customerSupportControl \
  --control-version LATEST \
  --treatment-bundle customerSupportTreatment \
  --treatment-version LATEST \
  --online-eval ABQualityMonitor \
  --control-weight 80 \
  --treatment-weight 20
```

**Traffic split:**
- 80% of new sessions → Control (current prompt)
- 20% of new sessions → Treatment (AI-recommended prompt)
- Both variants run on the same CustomerSupportAB runtime
- The Gateway assigns each new session to one variant and sticks with it

### Step 6: Policy Mode Change for A/B Traffic

The Cedar policies from Lab 7 are in ENFORCE mode and would block the A/B target (no permit exists for it). Switched to LOG_ONLY for the test:

```bash
jq '(.agentCoreGateways[] | select(.name == "my-gateway-secure") | .policyEngineConfiguration.mode) = "LOG_ONLY"' \
  agentcore/agentcore.json > agentcore/agentcore.json.tmp \
  && mv agentcore/agentcore.json.tmp agentcore/agentcore.json

agentcore deploy -y -v
```

**LOG_ONLY mode:** Policies are still evaluated and logged (you can see what would have been blocked), but they don't actually deny requests. This is the standard approach during experimentation.

### Step 7: Load Generation & Results

Sent 30 requests through the Gateway using a load-gen script with 6 rotating prompts:

| Prompt | What it tests |
|--------|---------------|
| "What's the price of the Smart Watch?" | Product lookup (get_product_info) |
| "My headphones are broken, what should I do?" | Return policy + product knowledge |
| "Is PROD-002 still under warranty?" | Warranty check (Gateway → Lambda) |
| "What's the return policy for audio products?" | Return policy by category |
| "It stopped working. Can I get a refund?" | Ambiguous request (needs clarification) |
| "I want to return my USB-C Hub and check its warranty." | Multi-tool: product lookup + return policy + warranty |

**A/B Test Status:**
```json
{
  "id": "customersupport_cs_prompt_abtest-9434239c01",
  "status": "ACTIVE",
  "lifecycleStatus": "RUNNING",
  "variants": [
    {"name": "C", "weight": 80, "bundle": "customerSupportControl"},
    {"name": "T1", "weight": 20, "bundle": "customerSupportTreatment"}
  ]
}
```

**Interpreting results (when they arrive ~15 min after traffic):**

| Result | Interpretation | Action |
|--------|---------------|--------|
| p-value < 0.05 AND positive percentChange | Treatment is significantly better | Promote the treatment |
| p-value < 0.05 AND negative percentChange | Treatment is significantly worse | Keep the control |
| p-value >= 0.05 | Not enough evidence yet | Keep collecting samples or raise treatment weight |

```bash
# Check results
agentcore view ab-test $AB_TEST_ID --json

# Stop and archive when done
agentcore stop ab-test -i $AB_TEST_ID
agentcore archive ab-test -i $AB_TEST_ID
```

### Actual A/B Test Results

```json
{
  "analysisTimestamp": 1787440441.265,
  "evaluatorMetrics": [{
    "evaluator": "Builtin.GoalSuccessRate",
    "controlStats": {"mean": 0.50, "sampleSize": 24, "variantName": "C"},
    "variantResults": [{
      "mean": 0.50,
      "sampleSize": 6,
      "percentChange": 0,
      "pValue": 1.0,
      "isSignificant": false,
      "confidenceInterval": {"lower": -0.4473, "upper": 0.4473},
      "variantName": "T1"
    }]
  }]
}
```

| Metric | Control (C) | Treatment (T1) | Result |
|--------|-------------|----------------|--------|
| GoalSuccessRate mean | 0.50 | 0.50 | Tied |
| Sample size | 24 sessions | 6 sessions | Low power |
| percentChange | — | 0% | No difference |
| pValue | — | 1.0 | Not significant |
| isSignificant | — | false | Cannot reject null hypothesis |
| Confidence interval | — | [-0.45, +0.45] | Crosses zero (inconclusive) |

**Verdict: INCONCLUSIVE — keep the control.**

**Why no winner was detected:**
- Only 6 treatment samples (20% of 30 = ~6 sessions) — far too few for statistical power
- Both scored 50% GoalSuccessRate — the prompts performed equivalently at this scale
- The confidence interval [-0.45, +0.45] is extremely wide, meaning the true difference could be anywhere from -45% to +45%
- In production, you'd run this for days/weeks with thousands of sessions to get meaningful results

**What this proves:** The A/B testing infrastructure works correctly. The Gateway split traffic, both bundles were applied, the online eval scored sessions, and statistical analysis was performed. At workshop scale (30 requests), you simply can't detect small prompt improvements — that requires production-scale traffic.

### Step 8: Promote the Winner

When the treatment wins (isSignificant: true, pValue < 0.05, positive percentChange, confidence interval doesn't cross zero):

1. Update the system prompt in your production agent (`main.py`) to use the winning prompt
2. Update tool descriptions if the tool-description recommendations also showed improvement
3. The winning variant's traces become the new baseline for your next optimization round

**In our case:** No winner, so we keep the control and would need more traffic to reach a conclusion.

### Architecture After Lab 9

```
                         ┌──────────────────────────────────────┐
                         │           AgentCore Gateway           │
                         │         (my-gateway-secure)           │
                         │                                       │
                         │  Targets:                             │
                         │  ├─ WarrantyCheck (Lambda)            │
                         │  ├─ ProcessRefund (Lambda)            │
                         │  └─ customer-support-ab (http-runtime)│
                         │                                       │
                         │  Policy Engine: LOG_ONLY mode         │
                         │  A/B Test: cs_prompt_abtest (RUNNING) │
                         │    ├─ 80% → Control bundle            │
                         │    └─ 20% → Treatment bundle          │
                         └───────────────────┬──────────────────┘
                                             │
              ┌──────────────────────────────┼───────────────────────────┐
              │                              │                           │
   ┌──────────▼──────────┐    ┌─────────────▼────────────┐   ┌─────────▼──────────┐
   │  CustomerSupport     │    │  CustomerSupportAB        │   │  OrderResearchAgent │
   │  (Production)        │    │  (A/B Experimentation)    │   │  (Harness)          │
   │                      │    │                           │   │                     │
   │  • CUSTOM_JWT auth   │    │  • IAM auth (GW only)     │   │  • OAuth M2M        │
   │  • Memory enabled    │    │  • No memory (stateless)  │   │  • Code Interpreter │
   │  • QualityMonitor    │    │  • ABQualityMonitor        │   │  • HITL             │
   │  • Fixed prompt      │    │  • Dynamic prompt (bundle) │   │  • Skills           │
   └──────────────────────┘    └────────────────────────────┘   └─────────────────────┘
```

### The Full Optimization Loop (What Lab 9 Represents)

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTINUOUS IMPROVEMENT CYCLE                   │
│                                                                   │
│  1. OBSERVE: Agent runs in production → traces collected auto    │
│       ↓                                                           │
│  2. ANALYZE: `agentcore run recommendation` → AI reads traces   │
│       ↓                                                           │
│  3. HYPOTHESIZE: Generates optimized prompts/tool descriptions  │
│       ↓                                                           │
│  4. PACKAGE: Config bundles (control vs treatment)               │
│       ↓                                                           │
│  5. TEST: A/B test on live traffic (80/20 split)                │
│       ↓                                                           │
│  6. MEASURE: Online eval scores both variants automatically      │
│       ↓                                                           │
│  7. DECIDE: Statistical significance → promote or reject        │
│       ↓                                                           │
│  8. PROMOTE: Winner becomes new production prompt                │
│       ↓                                                           │
│  (repeat — winner's traces become next round's baseline)         │
└─────────────────────────────────────────────────────────────────┘
```

**This is NOT "loop engineering."** It's a one-time analysis + controlled experiment pattern. You run it when you want to improve, not continuously in a loop. Each cycle is: collect evidence → form hypothesis → test hypothesis → apply if validated.

### Key Changes in Lab 9

| File | Change |
|------|--------|
| `app/CustomerSupportAB/main.py` | NEW — Config-bundle-aware A/B agent with BeforeModelCallEvent hook |
| `app/CustomerSupportAB/pyproject.toml` | NEW — Dependencies for AB runtime |
| `agentcore/agentcore.json` | Added: CustomerSupportAB runtime, config bundles (control + treatment), ABQualityMonitor, customer-support-ab gateway target, policy mode → LOG_ONLY |

### Deployed Resources After Lab 9

| Resource | Count | Details |
|----------|-------|---------|
| Runtimes | 2 | CustomerSupport (production, JWT), CustomerSupportAB (A/B, IAM) |
| Memories | 1 | SharedMemory (SEMANTIC + SUMMARIZATION) |
| Credentials | 1 | gateway-egress-oauth (OAuth for Harness) |
| Gateways | 1 | my-gateway-secure (3 targets: WarrantyCheck, ProcessRefund, customer-support-ab) |
| Online Eval Configs | 2 | QualityMonitor (3 evaluators), ABQualityMonitor (1 evaluator) |
| Policy Engines | 1 | CustomerSupportPolicyEngine (4 policies, LOG_ONLY mode) |
| Config Bundles | 2 | customerSupportControl, customerSupportTreatment |
| Harnesses | 3 | OrderResearchAgent, PersistentReportAgent, ContainerAgent |
| A/B Tests | 1 | cs_prompt_abtest (RUNNING, 80/20 split) |

### Commands Summary

```bash
# Generate recommendations from traces
agentcore run recommendation --type system-prompt --runtime CustomerSupport --name cs-prompt-rec --days 1
agentcore run recommendation --type tool-description --runtime CustomerSupport --name cs-tool-rec --days 1

# Create A/B runtime
agentcore add agent --name CustomerSupportAB --language Python --framework Strands --model-provider Bedrock --memory none --build CodeZip

# Add gateway target for A/B
agentcore add gateway-target --name customer-support-ab --gateway my-gateway-secure --type http-runtime --runtime CustomerSupportAB

# Create config bundles
agentcore add config-bundle --name customerSupportControl --commit-message "Baseline prompt" --components '...'
agentcore add config-bundle --name customerSupportTreatment --commit-message "Recommended prompt" --components '...'

# Create A/B online eval
agentcore add online-eval --name ABQualityMonitor --runtime CustomerSupportAB --evaluator Builtin.GoalSuccessRate --sampling-rate 100 --enable-on-create

# Deploy everything
agentcore deploy -y -v

# Launch A/B test
agentcore run ab-test --mode config-bundle --name cs_prompt_abtest --gateway my-gateway-secure --runtime CustomerSupportAB --control-bundle customerSupportControl --control-version LATEST --treatment-bundle customerSupportTreatment --treatment-version LATEST --online-eval ABQualityMonitor --control-weight 80 --treatment-weight 20

# Switch policies to LOG_ONLY for test
jq '...' agentcore/agentcore.json > tmp && mv tmp agentcore/agentcore.json
agentcore deploy -y -v

# Generate load
bash loadgen.sh

# Check results
agentcore view ab-test $AB_TEST_ID --json

# Cleanup
agentcore stop ab-test -i $AB_TEST_ID
agentcore archive ab-test -i $AB_TEST_ID
```

---

## Workshop Complete — Full Architecture Summary

| Lab | What You Built | Key Concept |
|-----|---------------|-------------|
| 1 | Agent prototype with local tools | Strands SDK + AgentCore Runtime |
| 2 | Persistent memory across sessions | SEMANTIC + SUMMARIZATION strategies |
| 3 | Centralized tools via Gateway | MCP protocol, Lambda targets |
| 4 | Security with JWT authentication | Cognito, CUSTOM_JWT, verified identity |
| 5 | Continuous quality monitoring | Online eval, LLM-as-a-Judge |
| 6 | Customer-facing chat interface | Flask + REST API + streaming |
| 7 | Fine-grained governance | Cedar policies, default-deny |
| 8 | Zero-code agents | Harness, OAuth M2M, HITL, Skills |
| 9 | Data-driven optimization | Traces → Recommendations → A/B test → Promote |
