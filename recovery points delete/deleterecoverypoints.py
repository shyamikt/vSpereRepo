import requests

# Nutanix Prism Central API endpoint
base_url = "https://your_prism_central_ip:9440/api/nutanix/v3"

# Authentication
auth_url = f"{base_url}/auth/tokens"
auth_data = {"username": "your_username", "password": "your_password"}
response = requests.post(auth_url, json=auth_data, verify=False)
token = response.json()["metadata"]["authorization_token"]
headers = {"Authorization": f"Bearer {token}"}

# Get VMs
vm_url = f"{base_url}/vms"
response = requests.get(vm_url, headers=headers, verify=False)
vms = response.json()["entities"]

# Iterate through VMs
for vm in vms:
    vm_id = vm["metadata"]["uuid"]
    
    # Get snapshots for the VM
    snapshots_url = f"{vm_url}/{vm_id}/snapshots"
    response = requests.get(snapshots_url, headers=headers, verify=False)
    snapshots = response.json()["entities"]
    
    # Iterate through snapshots
    for snapshot in snapshots:
        snapshot_id = snapshot["metadata"]["uuid"]
        
        # Delete snapshots based on criteria (e.g., age, retention policy)
        # Add your logic here
        
        # Example: Delete all snapshots
        delete_url = f"{snapshots_url}/{snapshot_id}"
        response = requests.delete(delete_url, headers=headers, verify=False)
        if response.status_code == 200:
            print(f"Snapshot {snapshot_id} deleted successfully")
        else:
            print(f"Failed to delete snapshot {snapshot_id}: {response.text}")