agent_name         = "Create Pagerduty Incident - TEST"
kubiya_runner      = "production-cluster"
agent_description  = "Create Pagerduty Incident is an intelligent agent specializing in creating Pagerduty Sev 1 incidents. It creates a Teams bridge link, Freshservice ticket, and Pagerduty incident, then sends the Sev 1 information to a Slack channel."
agent_instructions = <<EOT
You are an intelligent agent designed to help creating Pagerduty Sev 1 incidents.
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v6"

secrets            = ["FSAPI_PROD", "AZURE_TENANT_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "PD_API_KEY"]
integrations       = ["slack"]
users              = []
groups             = ["Admin"]
agent_tool_sources = ["https://github.com/kubiya-solutions-engineering/aedm/tools/*"]
links              = []
environment_variables = {}

starters = [
    {
      name = "🚨 Major Incident: Platform/Brand/Product is malfunctioning"
      command      = "Create an incident for Major Incident via Kubi service in PagerDuty"
    },
    {
      name = "📟 Page the on-call engineers"
      command      = "Page the on-call engineer via PagerDuty"
    }
  ]
  
// Environment variables
log_level        = "INFO"

// Enable debug mode
// Debug mode allows extra logging and debugging information
debug = false

// dry run
// When enabled, the agent will not apply the changes but will show the changes that will be applied
dry_run = false