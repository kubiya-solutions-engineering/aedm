#!/usr/bin/env python3

import os
import requests
import json
import argparse

def create_pd_incident(description):
    url = "https://api.pagerduty.com/incidents"
    headers = {
        "Authorization": f"Token token={os.getenv('PD_API_KEY')}",
        "Content-Type": "application/json"
    }
    payload = {
        "incident": {
            "type": "incident",
            "title": f"Assistance requested via Kubi - {description}",
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
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    if response.status_code == 201:
        return response.json()["incident"]["id"]
    else:
        raise Exception(f"Failed to create incident: {response.text}")

def main(description):
    if not description:
        print("Usage: page-oncall-engineer.py --description <description>")
        return

    pd_incident_id = create_pd_incident(description)
    print(f"The on-call engineer has been paged. They will reach out to you as soon as possible. Your PagerDuty incident URL is https://aetnd.pagerduty.com/incidents/{pd_incident_id}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Page the on-call engineer via PagerDuty.")
    parser.add_argument("--description", required=True, help="The description of the problem.")
    args = parser.parse_args()
    main(args.description)
