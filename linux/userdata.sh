#!/bin/bash

exec &> ${tfi_lx_userdata_log}

start=`date +%s`

WATCHMAKER_INSTALL_GOES_HERE

end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

setenforce 0

# open firewall (iptables for rhel/centos 6, firewalld for 7
systemctl status firewalld > /dev/null
if [ $? -eq 0 ] ; then
  echo "Configuring firewalld..."
  firewall-cmd --zone=public --permanent --add-port=122/tcp
  firewall-cmd --reload
else
  echo "Configuring iptables..."
  iptables -A INPUT -p tcp --dport 122 -j ACCEPT #open port 122
  iptables save
  iptables restart
fi

sed -i -e '5iPort 122' /etc/ssh/sshd_config
sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
cat /etc/ssh/sshd_config
service sshd restart

# get OS version as key prefix
export S3_KEYFIX=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9]\.[0-9]\).*/\1/')

aws s3 cp ${tfi_lx_userdata_log} "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${S3_KEYFIX}/userdata.log" || true
aws s3 cp /var/log "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${S3_KEYFIX}/cloud-init/" --recursive --exclude "*" --include "cloud*log" || true
aws s3 cp /var/log/watchmaker "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${S3_KEYFIX}/watchmaker/" --recursive || true

touch /tmp/SETUP_COMPLETE_SIGNAL
