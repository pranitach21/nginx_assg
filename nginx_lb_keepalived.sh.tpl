#!/bin/bash

exec > /var/log/keepalived_setup.log 2>&1

peer_ip=${peer_ip}
state=${state}
vip=${vip}
priority=${priority}
interface=${interface}
eip_id=${eip_id}
region=${region}
backend_1=${backend_1}
backend_2=${backend_2}
private_ip=${private_ip}

# Install required packages
yum update -y
amazon-linux-extras enable nginx1
yum clean metadata
yum install -y nginx keepalived awscli

# Configure NGINX reverse proxy with round-robin load balancing
# Configure NGINX reverse proxy with round-robin load balancing
cat > /etc/nginx/nginx.conf <<EOF
events {}

http {
    keepalive_timeout 0;
    upstream backend {
        server ${backend_1};
        server ${backend_2};
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_http_version 1.0; 
            proxy_set_header Connection close;
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;

        }
    }
}
EOF



systemctl restart nginx
systemctl enable nginx

# Configure Keepalived
cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state ${state}
    interface ${interface}
    virtual_router_id 51
    priority ${priority}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 42
    }
    unicast_src_ip ${private_ip}
    unicast_peer {
        ${peer_ip}
    }
    virtual_ipaddress {
        ${vip}
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
}
EOF

# Notify master script
cat > /etc/keepalived/notify_master.sh <<EOF
#!/bin/bash
aws ec2 associate-address --instance-id \$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --allocation-id ${eip_id} --region ${region}
EOF

chmod +x /etc/keepalived/notify_master.sh

# Notify backup script
cat > /etc/keepalived/notify_backup.sh <<EOF
#!/bin/bash
# echo "Now BACKUP node"
EOF

chmod +x /etc/keepalived/notify_backup.sh

# Enable and start Keepalived
systemctl enable keepalived
systemctl restart keepalived


# Set up simulated failover cron job only on MASTER
if [ "${state}" == "MASTER" ]; then
    echo "Setting up cron job for master failover simulation..."

    # Install cronie and atd (required for cron + delayed restart)
    yum install -y cronie at

    systemctl enable crond
    systemctl start crond
    systemctl enable atd
    systemctl start atd

    # Create the failover simulation script
    cat > /usr/local/bin/simulate_failover.sh <<'EOF'
#!/bin/bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION="${region}"

# Schedule instance start in 15 mins
echo "aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION" | at now + 15 minutes

# Stop instance to simulate failover
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION
EOF

    chmod +x /usr/local/bin/simulate_failover.sh

    # Add cron job to run this every hour
    (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/simulate_failover.sh") | crontab -

    echo "Cron job setup complete."
fi
