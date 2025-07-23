
- **solution.tf** — Defines the infrastructure (EC2 instances, networking, user data).
- **user_data_node_a.sh** — Configures Node A to serve static HTML: `"This is Node A"`.
- **user_data_node_b.sh** — Configures Node B to serve static HTML: `"This is Node B"`.
- **nginx_lb_keepalived.sh.tpl** — Bootstraps the load balancers with:
  - NGINX reverse proxy config.
  - Keepalived VRRP setup.

---

## ⚙️ Infrastructure Details

| Tier         | Nodes           | Purpose                          |
|--------------|-----------------|----------------------------------|
| Backend App  | Node A, Node B  | Serve static HTML pages.         |
| Load Balancer| LB1, LB2        | Reverse proxy + VIP failover.    |
| VIP          | Floating IP     | Moves automatically between LBs. |

---

## 🚀 Deployment Guide

### 1️⃣ Clone This Repository

```bash
git clone <your-repo-url>
cd <repo-name>


2️⃣ Initialize and Apply Terraform
terraform init
terraform apply
What happens:

2 backend web servers are created with user_data_node_a.sh and user_data_node_b.sh.

2 load balancer nodes are created with nginx_lb_keepalived.sh.tpl.

3️⃣ Verify Backend Nodes
Once provisioned, check that Node A and Node B serve unique content:

bash
Copy
Edit
curl http://<Node A Public IP>
# Output: <h1>This is Node A</h1>

curl http://<Node B Public IP>
# Output: <h1>This is Node B</h1>
4️⃣ Verify Load Balancer
Your load balancers are configured to:

Listen on port 80.

Forward requests to both backend servers with round-robin.

Get your VIP (defined in your Keepalived config).

Test:

bash
Copy
Edit
curl http://<VIP>
# Output should alternate between:
# <h1>This is Node A</h1>
# <h1>This is Node B</h1>
Try curl multiple times to confirm round-robin is working.

🔁 Simulate Failover
1️⃣ Check which LB holds the VIP

On LB1:

bash
Copy
Edit
ip addr | grep <VIP>
2️⃣ Stop Keepalived on the active LB

bash
Copy
Edit
sudo systemctl stop keepalived
3️⃣ Verify VIP moves to the standby LB

On LB2:

bash
Copy
Edit
ip addr | grep <VIP>
4️⃣ Test again

bash
Copy
Edit
curl http://<VIP>
# Output still shows Node A / Node B, proving no downtime.