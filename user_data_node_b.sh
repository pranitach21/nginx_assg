#!/bin/bash
set -e

yum update -y
amazon-linux-extras enable nginx1
yum install -y nginx

echo "<h1>This is Node B</h1>" > /usr/share/nginx/html/index.html

systemctl start nginx
systemctl enable nginx
