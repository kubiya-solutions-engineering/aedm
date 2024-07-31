#!/usr/bin/env python3

import os
import requests
import json
import argparse
from datetime import datetime, timedelta

def get_access_token():
    url = f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token"
    payload = {
        'client_id': os.getenv('AZURE_CLIENT_ID'),
        'scope': 'https://graph.microsoft.com/.default',
        'client_secret': os.getenv('AZURE_CLIENT_SECRET'),
        'grant_type': 'client_credentials'
    }
    response = requests.post(url, data=payload)
    response.raise_for_status()
    return response.json().get('access_token')

def get_oncall_engineer():
    url = "https://api.pagerduty.com/oncalls"
    headers = {
        "Authorization": f"Token token={os.getenv('PD_API_KEY')}",
        "Accept": "application/vnd.pagerduty+json;version=2"
    }
    response = requests.get(url, headers=headers, params={"time_zone": "UTC"})
    response.raise_for_status()
    oncalls = response.json().get('oncalls', [])
    for oncall in oncalls:
        if oncall.get('schedule') and oncall['schedule'].get('id') == "PUSDB5G":  # Replace with your actual schedule ID
            return oncall['user']['summary']
    return "Incident Commander"

def create_pd_incident(description):
    url = "https://api.pagerduty.com/incidents"
    headers = {
        "Authorization": f"Token token={os.getenv('PD_API_KEY')}",
        "Content-Type": "application/json",
        "From": os.getenv('KUBIYA_USER_EMAIL')
    }
    payload = {
        "incident": {
            "type": "incident",
            "title": f"Major Incident via Kubi - {description}",
            "service": {
                "id": "PUSDB5G",
                "type": "service_reference"
            },
            "escalation_policy": {
                "id": "PPBZA76",
                "type": "escalation_policy_reference"
            },
            "body": {
                "type": "incident_body",
                "details": description
            }
        }
    }
    print(f"Payload: {json.dumps(payload, indent=2)}")
    print(f"Headers: {headers}")
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    print(f"Response Status Code: {response.status_code}")
    print(f"Response Body: {response.text}")
    response.raise_for_status()
    return response.json()["incident"]["id"]

def create_ticket(description, incident_id, incident_commander):
    url = "https://aenetworks.freshservice.com/api/v2/tickets"
    user_email = os.getenv('KUBIYA_USER_EMAIL')
    payload = {
        "description": f"{description}<br><strong>Incident Commander:</strong> {incident_commander}<br><strong>Detection Method:</strong> Detection Method<br><strong>Business Impact:</strong> Business Impact<br><strong>Ticket Link:</strong>PagerDuty Incident",
        "subject": f"MAJOR INCIDENT pagerduty-kubiya-page-oncall-service - Major Incident via Kubi",
        "email": user_email,
        "priority": 1,
        "status": 2,
        "source": 8,
        "category": "DevOps",
        "sub_category": "Pageout",
        "tags": [f"PDID_{incident_id}"]
    }
    response = requests.post(url, headers={"Content-Type": "application/json"}, auth=(os.getenv('FSAPI_PROD'), "X"), data=json.dumps(payload))
    response.raise_for_status()
    return response.json()["ticket"]["id"]

def create_meeting(access_token):
    url = "https://graph.microsoft.com/v1.0/users/d69debf1-af1f-493f-8837-35747e55ea0f/onlineMeetings"
    start_time = datetime.utcnow()
    end_time = start_time + timedelta(hours=1)
    payload = {
        "startDateTime": start_time.isoformat() + "Z",
        "endDateTime": end_time.isoformat() + "Z"
    }
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    response.raise_for_status()
    return response.json()["joinUrl"]

def send_slack_message(channel, message):
    url = "https://slack.com/api/chat.postMessage"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {os.getenv('SLACK_API_TOKEN')}"
    }
    payload = {
        "channel": channel,
        "text": message
    }
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    response.raise_for_status()

def main(description):
    if not description:
        print("Usage: trigger-major-incident-communication.py --description <description>")
        return

    access_token = get_access_token()
    incident_commander = get_oncall_engineer()
    pd_incident_id = create_pd_incident(description)
    ticket_id = create_ticket(description, pd_incident_id, incident_commander)
    ticket_url = f"https://aenetworks.freshservice.com/a/tickets/{ticket_id}"
    meeting_link = create_meeting(access_token)

    message = f"""
    ************** SEV 1 ****************
    <@U04UKPX585S>
    Incident Commander: {incident_commander}
    Detection Method: Detection Method
    Business Impact: Business Impact
    Bridge Link: <{meeting_link}|Bridge Link>
    PagerDuty Incident URL: https://aetnd.pagerduty.com/incidents/{pd_incident_id}
    FS Ticket URL: {ticket_url}
    We will keep everyone posted on this channel as we assess the issue further.
    """
    send_slack_message("#kubiya_testing", message.strip())

    print("Please go to the #kubiya_testing channel to find the SEV1 announcement. The bridge line and pertinent details have been posted there. Thank you.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Trigger Major Incident Response.")
    parser.add_argument("--description", required=True, help="The description of the incident.")
    args = parser.parse_args()
    main(args.description)
