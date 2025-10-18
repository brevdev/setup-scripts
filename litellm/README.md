# LiteLLM

Universal LLM proxy - use any LLM with OpenAI API format.

## What it installs

- **LiteLLM proxy** - Universal API gateway for LLMs
- **Docker container** - Runs as background service
- **Example config** - Pre-configured for OpenAI, Anthropic, Ollama

## Features

- **100+ LLM support** - OpenAI, Anthropic, Cohere, Azure, AWS Bedrock, etc.
- **OpenAI-compatible** - Use any LLM with OpenAI SDK
- **Easy switching** - Change models without code changes
- **Load balancing** - Distribute requests across models
- **Cost tracking** - Built-in usage monitoring
- **Caching** - Redis-compatible response caching

## ⚠️ Required Port

To access from outside Brev, open:
- **4000/tcp** (LiteLLM API endpoint)

## Usage

```bash
bash setup.sh
```

Takes ~1-2 minutes.

## What you get

- **API Endpoint:** `http://localhost:4000`
- **Config file:** `~/.litellm/config.yaml`
- **Example script:** `~/.litellm/example.py`

## Quick Start

**1. Add your API keys:**
```bash
nano ~/.litellm/.env
# Add:
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
```

**2. Restart the proxy:**
```bash
docker restart litellm
```

**3. Use with any OpenAI SDK:**
```python
import openai

openai.api_base = "http://localhost:4000"
openai.api_key = "anything"

response = openai.ChatCompletion.create(
    model="gpt-4",  # or claude-3-5-sonnet
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## Configuration

Edit `~/.litellm/config.yaml`:

```yaml
model_list:
  # Add any model
  - model_name: my-gpt4
    litellm_params:
      model: gpt-4
      api_key: os.environ/OPENAI_API_KEY
  
  # Use Ollama locally
  - model_name: llama3.2
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434
  
  # Load balance across models
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: gpt-3.5-turbo
      api_key: os.environ/OPENAI_API_KEY
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: azure/gpt-35-turbo
      api_key: os.environ/AZURE_API_KEY
```

## Supported Providers

- **OpenAI** - GPT-4, GPT-3.5, etc.
- **Anthropic** - Claude 3.5, Claude 3
- **Google** - Gemini, PaLM
- **AWS Bedrock** - Claude, Llama, etc.
- **Azure OpenAI** - All Azure models
- **Cohere** - Command, Embed
- **Ollama** - Local models
- **HuggingFace** - Any HF model
- **Replicate** - Any Replicate model
- And 90+ more!

## Examples

**Python:**
```python
import openai

openai.api_base = "http://localhost:4000"

# Use any model
response = openai.ChatCompletion.create(
    model="claude-3-5-sonnet",
    messages=[{"role": "user", "content": "Hello"}]
)
```

**cURL:**
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**JavaScript/TypeScript:**
```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://localhost:4000',
  apiKey: 'anything'
});

const response = await client.chat.completions.create({
  model: 'claude-3-5-sonnet',
  messages: [{ role: 'user', content: 'Hello!' }]
});
```

## Load Balancing

Route to fastest/cheapest model:

```yaml
model_list:
  - model_name: smart-router
    litellm_params:
      model: gpt-3.5-turbo
      api_key: os.environ/OPENAI_API_KEY
  - model_name: smart-router
    litellm_params:
      model: claude-instant-1
      api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  routing_strategy: simple-shuffle  # or latency-based-routing
```

## Cost Tracking

View usage:
```bash
docker logs litellm | grep cost
```

## Caching

Add Redis caching:
```yaml
litellm_settings:
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
```

## Health Check

```bash
curl http://localhost:4000/health
curl http://localhost:4000/models  # List available models
```

## Manage Service

```bash
docker ps                    # Check status
docker logs litellm          # View logs
docker logs -f litellm       # Follow logs
docker restart litellm       # Restart
docker stop litellm          # Stop
docker start litellm         # Start
```

## Update Config

After editing `~/.litellm/config.yaml`:
```bash
docker restart litellm
```

## Advanced Features

**Add authentication:**
```yaml
general_settings:
  master_key: sk-1234  # Set auth key
```

**Add fallbacks:**
```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: gpt-4
      api_key: os.environ/OPENAI_API_KEY
      fallbacks: [{"gpt-3.5-turbo": {"api_key": "os.environ/OPENAI_API_KEY"}}]
```

## Troubleshooting

**Container not running:**
```bash
docker logs litellm
docker restart litellm
```

**API key errors:**
- Check `~/.litellm/.env` is renamed from `.env.example`
- Verify keys are correct
- Restart: `docker restart litellm`

**Connection refused:**
- Check port 4000 is not in use: `lsof -i :4000`
- Verify container is running: `docker ps`

## Resources

- **Docs:** https://docs.litellm.ai/
- **GitHub:** https://github.com/BerriAI/litellm
- **Supported Models:** https://docs.litellm.ai/docs/providers

