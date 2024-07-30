#!/bin/bash

# Display the initial message
echo "We will now page the oncall engineer via PagerDuty. Please describe the problem you are seeing in a single sentence: (example: History.com is having an issue, the schedule for lifetime is not loading, etc)"

# Function to create an incident in PagerDuty
create_pd_incident() {
    local description="$1"
    local title="Assistance requested via Kubi"
    local incident_id=$(curl -X POST -H "Authorization: Token token=$PD_API_KEY" -H "Content-Type: application/json" -d "{
        \"incident\": {
            \"type\": \"incident\",
            \"title\": \"$title - $description\",
            \"service\": {
                \"id\": \"PUSDB5G\",
                \"type\": \"service_reference\"
            },
            \"escalation_policy\": {
                \"id\": \"PPBZA76\",
                \"type\": \"escalation_policy_reference\"
            },
            \"body\": {
                \"type\": \"incident_body\",
                \"details\": \"$description\"
            },
            \"priority\": {
                \"id\": \"P3\",
                \"type\": \"priority_reference\"
            }
        }
    }" "https://api.pagerduty.com/incidents" | jq -r '.incident.id')
    echo "$incident_id"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --description) description="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check for required arguments
if [ -z "${description}" ]; then
    echo "Usage: $0 --description <description>"
    exit 1
fi

# Confirmation step
confirmation=false
while [ "$confirmation" = false ]; do
    read -p "Are you sure you want to page the oncall engineer? (Yes/No): " user_input
    case $user_input in
        [Yy]* ) confirmation=true;;
        [Nn]* ) echo "Operation cancelled."; exit 1;;
        * ) echo "Please answer Yes or No.";;
    esac
done

# Create incident in PagerDuty
pd_incident_id=$(create_pd_incident "$description")

# Output the incident URL
echo "The on-call engineer has been paged. They will reach out to you as soon as possible. Your PagerDuty incident URL is https://aetnd.pagerduty.com/incidents/$pd_incident_id"
