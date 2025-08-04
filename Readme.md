# Website Setup Scripts

This script was used to build
[davidje13.com](https://www.davidje13.com/).

It will install various subdomain code (and necessary environments)
and install an nginx proxy server. It will also use the "let's encrypt"
service to get SSH keys for the site.
Security updates will be applied automatically. Other updates can be
applied by running:

```sh
sudo apt-get update;
sudo apt-get dist-upgrade -y;
sudo shutdown -r now;         # if needed
sudo apt-get autoremove -y;
```

The subdomain code will be refreshed automatically each day if changes
are found.

Updates to this repository can be applied by re-running the
`installer.sh` script.

# AWS Instance

## EC2

Use an ED25519 key pair
- for best security, generate a key locally:
   ```sh
   ssh-keygen -t ed25519 -N '' -C "website" -f ~/.ssh/website
   ```
- import the public key into AWS either via the UI
  (Network & Security &rarr; Key Pairs &rarr; Actions &rarr; Import Key Pair, copy contents of `website.pub` into box),
  or via the CLI:
  ```
  aws ec2 import-key-pair --key-name "website" --public-key-material "$(cat ~/.ssh/website.pub)"
  ```

Launch an instance with the following config:

- AMI: `ami-00d714618e1e1a7b0` (Debian 12, 64-bit, Arm)
- Architecture: ARM
- Instance Type: t4g.micro
- Key pair: as created earlier
- Use a security group which allows "All traffic" outbound (IPv4 and IPv6), and inbound traffic on:
  - 80 (public: `0.0.0.0/0` & `::/0`)
  - 443 (public: `0.0.0.0/0` & `::/0`)
  - 22 (your ip)
- Storage: 8GiB gp3
  - Encryption enabled (KMS key can be left as default, using aws/ebs)
  - IOPS: 3000
  - Throughput: 125
- Instance auto-recovery: Default
- Termination protection: Enable
- Credit specification: Standard

```json
{
  "MaxCount": 1,
  "MinCount": 1,
  "ImageId": "ami-00d714618e1e1a7b0",
  "InstanceType": "t4g.micro",
  "KeyName": "website",
  "DisableApiTermination": true,
  "EbsOptimized": true,
  "BlockDeviceMappings": [
    {
      "DeviceName": "/dev/sda1",
      "Ebs": {
        "Encrypted": true,
        "DeleteOnTermination": true,
        "Iops": 3000,
        "SnapshotId": "snap-05b63c7cce6fcdf1e",
        "VolumeSize": 8,
        "VolumeType": "gp3",
        "Throughput": 125
      }
    }
  ],
  "NetworkInterfaces": [
    {
      "AssociatePublicIpAddress": true,
      "DeviceIndex": 0,
      "Groups": ["<fill in>"]
    }
  ],
  "CreditSpecification": {
    "CpuCredits": "standard"
  },
  "PrivateDnsNameOptions": {
    "HostnameType": "ip-name",
    "EnableResourceNameDnsARecord": true,
    "EnableResourceNameDnsAAAARecord": false
  },
  "MaintenanceOptions": {
    "AutoRecovery": "default"
  }
}
```

After creation:

- assign an elastic IP (this can be done after the install script completes waiting on DNS changes if migrating an existing deployment)
- assign an IPv6 address (see below, from step 5 if IPv6 already configured for VPC)
- Disable metadata (Actions &rarr; Instance settings &rarr; Modify instance metadata options)
  Note: do not disable this when creating the instance, as it is required by AWS for configuring SSH keys.

## CloudWatch

- Restart if instance is down for 15 minutes
  - No notification
  - Action: "Reboot"
  - Thresholds:
    - Data: StatusCheckFailed: Instance
    - Group: Maximum
    - Period: 5 minutes
    - Consecutive Periods: 3

- Recover if system is down for 15 minutes
  - No notification
  - Action: "Recover"
  - Thresholds:
    - Data: StatusCheckFailed: System
    - Group: Maximum
    - Period: 5 minutes
    - Consecutive Periods: 3

## IPv6

To enable IPv6:

1. Go to the default VPC configuration (or whichever VPC the instance is in):
   1. Select "Actions" &rarr; "Edit CIDRs"
   2. Select "Add new IPv6 CIDR" and choose one of the options
      (davidje13.com uses "Amazon-provided")
2. Go to the subnet(s) your EC2 instance(s) are in. For each one:
   1. Select "Actions" &rarr; "Edit IPv6 CIDRs"
   2. Select "Add IPv6 CIDR", and enter any available value for the block
      (must be different for each subnet, and probably a good idea to start at `00` or `01`)
   3. Save
3. Still within the VPC section of AWS, go to the Route Table being used by the instance:
   1. Select "Actions" &rarr; "Edit Routes"
   2. Add the route destination: `::/0`, target: "Internet Gateway"
      (then select the same value already used for `0.0.0.0/0`)
   3. Save
4. Ensure the EC2 Security Group has been set up with `::/0` inbound rules, as described above.
   Also ensure it has an outbound rule for all traffic to `::/0` (this will be auto-created by
   the earlier steps, unless outbound rules have been customised)
5. Go to the EC2 Instance
   1. Select "Actions" &rarr; "Networking" &rarr; "Manage IP addresses"
   2. Expand "eth0" and in the "IPv6" section choose "Assign new IP address"
   3. Either enter a specific IP address (e.g. for migrating an existing deployment) or leave
      the field blank to assign a random IP address within the subnet range
   4. Select "Assign primary IPv6 IP"
      (this will ensure the IP address does not change, allowing easier Route 53 config)
   5. Save
6. Note the assigned IPv6 address and add `AAAA` records to Route53 (see below)

Full guide from AWS: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-migrate-ipv6.html>

## Route53

(skip `AAAA` record if IPv6 has not been configured)

| type  | name                | value                       | ttl    |
|-------|---------------------|-----------------------------|--------|
| A     | `<domain>`          | `<elastic ip>`              | 1 hour |
| AAAA  | `<domain>`          | `<ipv6>`                    | 1 hour |
| CNAME | `www.<domain>`      | `<domain>`                  | 7 days |
| CNAME | `retro.<domain>`    | `<domain>`                  | 7 days |
| CNAME | `retros.<domain>`   | `<domain>`                  | 7 days |
| CNAME | `refacto.<domain>`  | `<domain>`                  | 7 days |
| CNAME | `sequence.<domain>` | `<domain>`                  | 7 days |
| CAA   | `<domain>`          | `0 issue "letsencrypt.org"` | 7 days |

If the domain will not send email, the following should also be added:

| type | name                    | value                              | ttl   |
|------|-------------------------|------------------------------------|-------|
| TXT  | `<domain>`              | `v=spf1 -all`                      | 1 day |
| TXT  | `*._domainkey.<domain>` | `v=DKIM1;p=`                       | 1 day |
| TXT  | `_dmarc.<domain>`       | `v=DMARC1;p=reject;adkim=s;aspf=s` | 1 day |

([source](https://www.cloudflare.com/learning/dns/dns-records/protect-domains-without-email/))

## Installation

Once the EC2 & Route53 config is done, log in to the box:

```sh
ssh -i ~/.ssh/website admin@<public-address>
```

and run:

```sh
git clone https://github.com/davidje13/Website.git
Website/installer.sh
# this will probably ask for a restart, or will eventually complain about not having a domain
sudo shutdown -r now # SSH session will terminate - reconnect

cp Website/env/refacto.template.env Website/env/refacto.env

vi Website/env/refacto.env
# fill in any appropriate options then save

Website/installer.sh '<domain>'
```

The script will automatically wait for DNS records to be configured when
needed, so you do not have to set up the DNS before running the script.

## Backup and restore

You can backup and restore the Refacto database using the commands:

```sh
Website/refacto/backup.sh # generates backup-*.tar.gz
```

```sh
# restore from backup-2020-10-03T12-00-00.tar.gz
Website/refacto/restore.sh backup-2020-10-03T12-00-00.tar.gz
```

There is also an option to restore data from a backup file during
installation.

## Migrating

When migrating from an old server, downtime can be minimised by waiting until
the new server requests a backup file to load before shutting down and backing
up the old server:

1. Begin deployment of new server (follow steps above) until prompted with:
   "Enter filename to import refacto data from"
2. On old server, run:
   ```sh
   sudo systemctl stop refacto4080.service
   sudo systemctl stop refacto4081.service
   Website/refacto/backup.sh
   ```
3. Copy the generated backup file to the new server
4. Enter the filename in the prompt
5. Wait for the script to prompt:
   "Created background task waiting for (domain) DNS to point to this instance"
6. Reassign the elastic IPv4, and update the AAAA DNS entry to point to the new
   instance's IPv6.
   _Note: this will cause SSH sessions to end if they are using IPv4_
7. Installation should complete automatically.

## Checking logs

Services store logs in:

- `/var/www/sequence/logs/log*/*`
- `/var/www/refacto/logs/log*/*`
- `/var/log/nginx/*`

Sequence and Refacto use `multilog`'s `tai64n` format for timestamps.
These are not human-readable, but can be viewed with:

```sh
tai64nlocal < "my-log-file-here" | less
```

For example to see how often sequence diagram's render API is called:

```sh
cat /var/www/sequence/logs/log*/{*.s,current} | grep RENDER | sort
```

Old logs are `gzip`'ed. These can be viewed with:

```sh
gunzip -c "my-old-log-file-here.gz" | less
```

To view all recent nginx error logs:

```sh
( cat /var/log/nginx/error.log /var/log/nginx/error.log.1; gunzip -c /var/log/nginx/error.log.*.gz ) \
| sort | cut -d' ' -f1,2,5- | less
```

To view all recent nginx access logs:

```sh
( cat /var/log/nginx/access.log /var/log/nginx/access.log.1; gunzip -c /var/log/nginx/access.log.*.gz ) \
| awk '{ print $4 " " $5 " " $1 " " substr($0, length($1 $2 $3 $4 $5) + 6) }' | sort | less
```

To view current firewall stats (e.g. number of packets to particular ports):

```sh
sudo nft list table inet filter
```

To view packets sent to unknown ports:

```sh
grep ' kernel:' < /var/log/syslog
```

## Post Setup

You should add the root domain to the
[HSTS preload list](https://hstspreload.org)
