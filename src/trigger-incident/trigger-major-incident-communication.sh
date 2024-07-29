#!/usr/bin/env bash

# Display the initial message
echo "This is for starting a Severity 1 Major Incident. Use only in the event of a major outage affecting the majority of the consumers. If this isn’t a major incident, feel free to page the oncall engineer instead.

Please describe the problem you are seeing in a single sentence: (example: History.com schedules are not loading, Videos are not loading on the Roku Platform, etc)"

# Function to obtain authentication token from Azure
get_access_token() {
    local url="https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token"
    local payload="client_id=$AZURE_CLIENT_ID&scope=https://graph.microsoft.com/.default&client_secret=$AZURE_CLIENT_SECRET&grant_type=client_credentials"
    local response=$(curl -s -X POST -d "$payload" "$url")
    echo "$response" | jq -r '.access_token'
}

# Function to create an incident in PagerDuty
create_pd_incident() {
    local description="$1"
    local title="Major Incident via Kubi"
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
                \"id\": \"P1\",
                \"type\": \"priority_reference\"
            }
        }
    }" "https://api.pagerduty.com/incidents" | jq -r '.incident.id')
    echo "$incident_id"
}

# Function to create a service ticket in FreshService
create_ticket() {
    local description="$1"
    local title="Major Incident via Kubi"
    local slackincidentcommander="Incident Commander"
    local slackdetectionmethod="Detection Method"
    local slackbusinessimpact="Business Impact"
    local incident_id="$2"
    local user_email="$KUBIYA_USER_EMAIL"
    local payload="{\"description\": \"$description</br><strong>Incident Commander:</strong>$slackincidentcommander</br><strong>Detection Method:</strong>$slackdetectionmethod</br><strong>Business Impact:</strong>$slackbusinessimpact</br><strong>Ticket Link:</strong>PagerDuty Incident\", \"subject\": \"MAJOR INCIDENT pagerduty-kubiya-page-oncall-service - $title\", \"email\": \"$user_email\", \"priority\": 1, \"status\": 2, \"source\": 8, \"category\": \"DevOps\", \"sub_category\": \"Pageout\", \"tags\": [\"PDID_$incident_id\"]}"
    curl -u $FSAPI_PROD:X -H "Content-Type: application/json" -X POST -d "$payload" -o response.json "https://aenetworks.freshservice.com/api/v2/tickets"
}

# Function to extract ticket ID from response
extract_ticket_id() {
    local ticket_id=$(jq -r '.ticket.id' response.json)
    echo "$ticket_id"
}

# Function to create a Teams bridge link
create_meeting() {
    local access_token="$1"
    local url="https://graph.microsoft.com/v1.0/users/d69debf1-af1f-493f-8837-35747e55ea0f/onlineMeetings"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%N%:z")
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%N%:z" -d "+1 hour")
    local payload='{"startDateTime":"'"$start_time"'","endDateTime":"'"$end_time"'"}'
    local response=$(curl -s -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -d "$payload" "$url")
    echo "$response" | jq -r '.joinUrl'
}

# Function to send a message to Slack
send_slack_message() {
    local channel="$1"
    local message="$2"
    curl -X POST -H 'Content-type: application/json' --data "{\"channel\":\"$channel\",\"text\":\"$message\"}" "https://slack.com/api/chat.postMessage" -H "Authorization: Bearer $SLACK_API_TOKEN"
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
    read -p "Thank you for this information. We will now generate a SEV1 announcement in #incident_response, generate a bridgeline, page the oncall engineers, and notify management of the incident. Are you sure you want to continue? (Yes/No): " user_input
    case $user_input in
        [Yy]* ) confirmation=true;;
        [Nn]* ) echo "Operation cancelled."; exit 1;;
        * ) echo "Please answer Yes or No.";;
    esac
done

# Get access token
access_token=$(get_access_token)

# Create incident in PagerDuty
pd_incident_id=$(create_pd_incident "$description")

# Create service ticket in FreshService
create_ticket "$description" "$pd_incident_id"

# Extract ticket ID
TICKET_ID=$(extract_ticket_id)

# Generate ticket URL
TICKET_URL="https://aenetworks.freshservice.com/a/tickets/$TICKET_ID"

# Create Teams bridge link
meeting_link=$(create_meeting "$access_token")

# Prepare Slack message
MESSAGE=$(cat <<EOF
************** SEV 1 ****************
<@U04UKPX585S>
Incident Commander: Incident Commander
Detection Method: Detection Method
Business Impact: Business Impact
Bridge Link: <$meeting_link|Bridge Link>
PagerDuty Incident URL: https://aetnd.pagerduty.com/incidents/$pd_incident_id
FS Ticket URL: $TICKET_URL
We will keep everyone posted on this channel as we assess the issue further.
EOF
)

# Send the message to the Slack channel
send_slack_message "#kubiya_testing" "$MESSAGE"

# Display completion message
echo "Please go to the #kubiya_testing channel to find the SEV1 announcement. The bridge line and pertinent details have been posted there. Thank you."
