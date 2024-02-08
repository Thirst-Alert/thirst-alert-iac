import os
import json
import requests

def populateMessage(attributes):
  type_url = attributes.get('type_url', 'N/A')
  cluster_name = attributes.get('cluster_name', 'N/A')
  project_id = attributes.get('project_id', 'N/A')
  payload = attributes.get('payload', {})

  return {
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": f"`{type_url.split('.')[-1]}`\nCluster: `{cluster_name}`\nProject number: `{project_id}`\nDetails:"
        }
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": f"```{json.dumps(json.loads(payload), indent=2)}```"
        }
      }
    ]
  }

def sendToSlack(event):
  print("hallo")
  print(event)