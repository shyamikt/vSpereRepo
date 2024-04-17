import requests

# Nutanix Prism Central API endpoint
base_url = "https://uk1upnutxpsmc01.pearsontc.com:9440/api/nutanix/v3"

# Authentication
auth_url = f"{base_url}/auth/tokens"
auth_data = {"username": "athamsh@dcsutil.dcsroot.local", "password": "g5NdSAiFwi"}
response = requests.post(auth_url, json=auth_data, verify=False)
token = response.json()["metadata"]["authorization_token"]
headers = {"Authorization": f"Bearer {token}"}

# Get VMs
vm_url = f"{base_url}/vms"
response = requests.get(vm_url, headers=headers, verify=False)
vms = response.json()["entities"]