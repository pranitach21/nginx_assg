***🚀 NGINX High Availability Assignment***


This project provisions a highly available reverse proxy setup using:

NGINX for load balancing

Keepalived for VIP failover

Terraform for infrastructure automation

***📁 Repository Contents***


| File                      | Purpose                                                       |
|---------------------------|---------------------------------------------------------------|
| `solution.tf`             | Defines infrastructure (EC2, VPC, user data, EIP)             |
| `user_data_node_a.sh`     | Node A user-data: serves static HTML ("This is Node A")       |
| `user_data_node_b.sh`     | Node B user-data: serves static HTML ("This is Node B")       |
| `nginx_lb_keepalived.sh.tpl` | Configures LBs with NGINX + Keepalived                   |

***⚙️ Infrastructure Overview**


| Tier           | Nodes           | Role                                        |
|----------------|------------------|---------------------------------------------|
| Backend App    | Node A, Node B   | Serve static HTML pages                     |
| Load Balancer  | LB1, LB2         | Reverse proxy with VIP failover             |
| VIP            | Floating IP      | Automatically moves between LBs             |

***🛠️ Deployment Guide***


**1️⃣ Clone This Repository**

```bash
Copy
Edit
gh repo clone pranitach21/nginx_assg
cd nginx_assg  ```
**2️⃣ Initialize and Apply Terraform**

```bash
Copy
Edit
terraform init
terraform apply
This will create:

2 backend EC2 instances using user_data_node_a.sh and user_data_node_b.sh

2 load balancers using nginx_lb_keepalived.sh.tpl

**3️⃣ Verify Backend Nodes**
Use the public IPs of each backend to confirm individual server responses:

```bash
Copy
Edit
curl http://<Node A Public IP>
# Output: <h1>This is Node A</h1>

curl http://<Node B Public IP>
# Output: <h1>This is Node B</h1>
**4️⃣ Verify Load Balancer Functionality**
The load balancer:

Listens on port 80

Uses round-robin to forward requests to Node A & B

Uses a virtual IP (VIP) that fails over if one LB fails

Test it:

```bash
Copy
Edit
curl http://<VIP>
# Output (on multiple tries):
# <h1>This is Node A</h1>
# <h1>This is Node B</h1>
***🔁 Simulate Failover***
**1️⃣ Check Which LB Owns the VIP**
On either LB:

```bash
Copy
Edit
ip addr | grep <VIP>
**2️⃣ Stop Keepalived on Active LB**
```bash
Copy
Edit
sudo systemctl stop keepalived
**3️⃣ Verify VIP Has Moved to the Standby LB**
```bash
Copy
Edit
ip addr | grep <VIP>
**4️⃣ Confirm High Availability**
```bash
Copy
Edit
curl http://<VIP>
# Output still switches between Node A / Node B
**✅ This shows the system is resilient with zero downtime.**
