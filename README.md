---------------------------------------------------------------------------------------
🚀 NGINX High Availability Assignment
-----------------------------------------------------------------------------------------------------

This project provisions a highly available reverse proxy setup using:

NGINX for load balancing

Keepalived for VIP failover

Terraform for infrastructure automation

----------------------------------------------------------------------------------
📁 Repository Contents
----------------------------------------------------------------------------------------------------


| File                      | Purpose                                                       |
|---------------------------|---------------------------------------------------------------|
| `solution.tf`             | Defines infrastructure (EC2, VPC, user data, EIP)             |
| `user_data_node_a.sh`     | Node A user-data: serves static HTML ("This is Node A")       |
| `user_data_node_b.sh`     | Node B user-data: serves static HTML ("This is Node B")       |
| `nginx_lb_keepalived.sh.tpl` | Configures LBs with NGINX + Keepalived                   |


------------------------------------------------------------------------------------------
⚙️ Infrastructure Overview
------------------------------------------------------------------------------------------------------


| Tier           | Nodes           | Role                                        |
|----------------|------------------|---------------------------------------------|
| Backend App    | Node A, Node B   | Serve static HTML pages                     |
| Load Balancer  | LB1, LB2         | Reverse proxy with VIP failover             |
| VIP            | Floating IP      | Automatically moves between LBs             |


----------------------------------------------------------------------------------------
🛠️ Deployment Guide
--------------------------------------------------------------------------------------------------------


***1️⃣ Clone This Repository***
```bash
gh repo clone pranitach21/nginx_assg
cd nginx_assg 
```

***2️⃣ Initialize AWS and Apply Terraform***
Download awscli and terraform from there offical sites.

```bash
aws configure
```   

Give secret key, access key and region. Also set profile name which will be updated in provider "aws" resource as profile

```
aws configure list-profiles 
```

list of all aws profiles will be listed select any one and run the following commands

```
set AWS_PROFILE=<name>
```

Run terraform commands

```
terraform init
terraform plan
terraform apply
```

 **This will create:**

 *2 backend EC2 instances using user_data_node_a.sh and user_data_node_b.sh*

 *2 load balancers using nginx_lb_keepalived.sh.tpl*

 *VIp will also be created*


<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/terraform_output.png" width="400">


***3️⃣ Verify Backend Nodes***

Use the public IPs of each backend to confirm individual server responses:

Copy the ips from the output given by terraform and run them on local / browser

🔵 LOCAL
```
curl http://<Node A Public IP>
```

🔵 ON BROWSER
```
http://<Node A Public IP>
```

**Output**

*This is Node A*

<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/node_a.png" width="400">

🔵 LOCAL
```
curl http://<Node B Public IP>
```

🔵 ON BROWSER
```
http://<Node AB Public IP>
```

**Output**

*This is Node B*

<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/node_b.png" width="400">


***4️⃣ Verify Load Balancer Functionality***

**The load balancer:**

Listens on port 80

Uses round-robin to forward requests to Node A & B

Uses a virtual IP (VIP) that fails over if one LB fails

Test it:

🔵 LOCAL
```
curl http://<VIP>
```

🔵 ON BROWSER
```
http://<VIP>
```

**Output (on multiple tries):**

*This is Node A* 

*This is Node B*

<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/eip_output_node_a.png" width="400">
<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/eip_output_node_b.png" width="400">


--------------------------------------------------------------------------------------
🔁 Simulate Failover
--------------------------------------------------------------------------------------------------


***1️⃣ Check Which LB Owns the VIP***

On either LB:
ssh / ssm in the server.

```bash
ip addr | grep <VIP>
```


***2️⃣ Stop Keepalived on Active LB***
```bash
sudo systemctl stop keepalived
```


***3️⃣ Verify VIP Has Moved to the Standby LB***
```bash
ip addr | grep <VIP>
```


***4️⃣ Confirm High Availability***

🔵 LOCAL
```
curl http://<VIP>
```

🔵 ON BROWSER
```
http://<VIP>
```

**Output :**

*still switches between Node A / Node B*

<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/eip_output_node_a.png" width="400">
<img src="https://raw.githubusercontent.com/pranitach21/nginx_assg/main/screenshots/eip_output_node_b.png" width="400">


---------------------------------------------------------------
## 🎬 Demo 
---------------------------------------------------------------------------

- 🔗 [Initial Setup & Working](https://github.com/pranitach21/nginx_assg/raw/main/videos/initial_setup&working.mp4)
- 🔗 [Testing Failover](https://github.com/pranitach21/nginx_assg/raw/main/videos/testing_failover.mp4)


**✅ This shows the system is resilient with zero downtime.**

🌱[Go to main branch](https://github.com/pranitach21/nginx_assg/tree/main)
