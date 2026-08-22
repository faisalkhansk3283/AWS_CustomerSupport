#!/bin/bash
TOKEN="eyJraWQiOiJ1VEtLRXV6Q1h0R0NzMFVaemw1WlI1ZWZMdlJaNjY3ZVRlM1VLS1oyd0k4PSIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiJhNGE4YjQ2OC01MGYxLTcwZTAtODUyOS0xNjYwMjk2NzQzZjYiLCJpc3MiOiJodHRwczovL2NvZ25pdG8taWRwLnVzLWVhc3QtMS5hbWF6b25hd3MuY29tL3VzLWVhc3QtMV9sQkNQUUlwTU4iLCJjbGllbnRfaWQiOiIxYXFiYTduNjhobWx2NjI4aWM0ajhwZmRpbSIsIm9yaWdpbl9qdGkiOiI2NzQxYTkyZC1kZDM4LTRmNDMtYjViYS0xNzA4ZmMyYzBhNDkiLCJldmVudF9pZCI6ImQ0N2Q3ODBkLWQ3MGYtNDhlZS1hYWJlLTdkNTU1N2U1NmUzNCIsInRva2VuX3VzZSI6ImFjY2VzcyIsInNjb3BlIjoiYXdzLmNvZ25pdG8uc2lnbmluLnVzZXIuYWRtaW4iLCJhdXRoX3RpbWUiOjE3ODc0MzY3NjQsImV4cCI6MTc4NzQ0MDM2NCwiaWF0IjoxNzg3NDM2NzY0LCJqdGkiOiI5ZTZmZDhkNS1jNDRmLTRjMDEtOWMzOS0zMWExZDNkYTU3ZjIiLCJ1c2VybmFtZSI6ImE0YThiNDY4LTUwZjEtNzBlMC04NTI5LTE2NjAyOTY3NDNmNiJ9.NV49b4_DrOqv6pGWDBKs8mbwpEHMI8dVmNnwGfst47d_7JV_0e_fKhY5vA-RvVQUni2i8AhO-7t_Lf1Uq65ek_sEXazXFITtDny3UGqD2efFIeJXwNBH8pUBQlB41rj2VXPIWAYf1jQcRToc1QeMuB2rl4dk1-vgEdztQvLR0BxNQXe7SNUjNJFirc84vkEBy5QEcepGsdIUX93xIAdSJzLjoWAxzGOGqtjgoaUCNXVQhJZFEe_7_RYCyZesCbk4Ib-aqGH4JI30L9H6vArD98i3CMq8fx8OlhvN4j2gzj_dWy1837u-fN4vDdWjW7RTTlhwpXZxdoeuhCwPFEUYww"
GATEWAY_URL="https://customersupport-my-gateway-secure-5a5z7ugftc.gateway.bedrock-agentcore.us-east-1.amazonaws.com/customer-support-ab/invocations"

PROMPTS=(
  "What's the price of the Smart Watch?"
  "My headphones are broken, what should I do?"
  "Is PROD-002 still under warranty?"
  "What's the return policy for audio products?"
  "It stopped working. Can I get a refund?"
  "I want to return my USB-C Hub and check its warranty."
)

for i in $(seq 1 30); do
  PROMPT="${PROMPTS[$(( (i - 1) % ${#PROMPTS[@]} ))]}"
  SESSION_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()) + '-' + str(uuid.uuid4())[:8])")
  echo "=== Request $i: $PROMPT ==="
  curl -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Amzn-Bedrock-AgentCore-Runtime-Session-Id: $SESSION_ID" \
    -d "{\"prompt\": \"$PROMPT\"}" \
    -X POST "$GATEWAY_URL"
  echo ""
  sleep 2
done
