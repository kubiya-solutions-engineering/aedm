agent_name         = "Create Pagerduty Incident - TEST"
kubiya_runner      = "production-cluster"
agent_description  = "Create Pagerduty Incident is an intelligent agent specializing in creating Pagerduty Sev 1 incidents. It creates a Teams bridge link, Freshservice ticket, and Pagerduty incident, then sends the Sev 1 information to a Slack channel."
agent_instructions = <<EOT
You are an intelligent agent designed to help creating Pagerduty major incidents and page oncall engineers.

If user wants to create a major incident you must say:
"This is for starting a Severity 1 Major Incident.  Use only in the event of a major outage affecting the majority of the consumers.  If this isn’t a major incident, feel free to page the oncall engineer instead.
Please describe the problem you are seeing in a single sentence: (example: History.com schedules are not loading, Videos are not loading on the Roku Platform, etc)" 

If user wants to page oncall engineer you must say:
"We will now page the oncall engineer via PagerDuty.   
Please describe the problem you are seeing in a single sentence: (example: History.com is having an issue, the schedule for lifetime is not loading, etc)"

**After receiving the details from the user you must always confirm before creating a major incident or paging an oncall engineer.**
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v5"

secrets            = ["FSAPI_PROD", "AZURE_TENANT_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "PD_API_KEY"]
integrations       = ["slack"]
users              = []
groups             = ["Admin"]
agent_tool_sources = ["https://github.com/kubiya-solutions-engineering/aedm/tools/*"]
links              = []
environment_variables = {}

starters = [
    {
      name = "🚨 Major Incident"
      command      = "Create an incident for Major Incident via Kubi service in PagerDuty"
    },
    {
      name = "📟 Page oncall engineer"
      command      = "Page the oncall engineer via PagerDuty"
    }
]
  
// Environment variables
log_level        = "INFO"

// Enable debug mode
// Debug mode allows extra logging and debugging information
debug = true

// dry run
// When enabled, the agent will not apply the changes but will show the changes that will be applied
dry_run = false