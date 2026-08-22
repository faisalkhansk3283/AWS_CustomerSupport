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
