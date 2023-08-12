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

- AMI: `ami-03ec287fa560a6ccc` (Ubuntu 20.04, Arm)
- T4g.micro
- "Credit specification": "Unlimited" off
- 8GB HDD, encryption enabled (using alias/aws/ebs)
- Use a security group which allows inbound traffic on:
  - 80 (public: `0.0.0.0/0` & `::/0`)
  - 443 (public: `0.0.0.0/0` & `::/0`)
  - 22 (your ip)
- (assign elastic IP)

## CloudWatch

- Restart if instance is down for 15 minutes
  - No notification
  - Action: "Reboot"
  - Thresholds:
    - StatusCheckFailed: Instance
    - Period: 5 minutes
    - Consecutive Periods: 3

- Recover if system is down for 15 minutes
  - No notification
  - Action: "Recover"
  - Thresholds:
    - StatusCheckFailed: System
    - Period: 5 minutes
    - Consecutive Periods: 3

Note: The CloudWatch web UI seems to have a few bugs; you may need to
check the alarms were created correctly (particularly whether they
include the chosen action). It may not be possible to create the
"recover" action (https://forums.aws.amazon.com/thread.jspa?threadID=329133)

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

(skip `AAAA` records if IPv6 has not been configured)

```
A    <domain>          <elastic ip>               (7days)
AAAA <domain>          <ipv6>                     (1day)
A    www.<domain>      <elastic ip>               (7days)
AAAA www.<domain>      <ipv6>                     (1day)
A    retro.<domain>    <elastic ip>               (7days)
AAAA retro.<domain>    <ipv6>                     (1day)
A    retros.<domain>   <elastic ip>               (7days)
AAAA retros.<domain>   <ipv6>                     (1day)
A    refacto.<domain>  <elastic ip>               (7days)
AAAA refacto.<domain>  <ipv6>                     (1day)
A    sequence.<domain> <elastic ip>               (7days)
AAAA sequence.<domain> <ipv6>                     (1day)
CAA  <domain>          0 issue "letsencrypt.org"  (7days)
```

If the domain will not send email, the following should also be added:

```
TXT <domain>              v=spf1 -all                      (1day)
TXT *._domainkey.<domain> v=DKIM1;p=                       (1day)
TXT _dmarc.<domain>       v=DMARC1;p=reject;adkim=s;aspf=s (1day)
```

([source](https://www.cloudflare.com/learning/dns/dns-records/protect-domains-without-email/))

## Installation

Once the EC2 & Route53 config is done, log in to the box and run:

```sh
git clone https://github.com/davidje13/Website.git
cp Website/env/refacto.template.env Website/env/refacto.env

vi Website/env/refacto.env
# fill in any appropriate options then save

Website/installer.sh '<domain>'
```

You may need to restart and run `Website/installer.sh '<domain>'` again
after the restart completes. The script will pause and wait for input
before it needs the DNS records configured, so you do not have to set
up the DNS before running the script.

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

Old logs are `gzip`'ed. These can be viewed with:

```sh
gunzip -c "my-old-log-file-here.gz" | less
```

## Post Setup

You should add the root domain to the
[HSTS preload list](https://hstspreload.org)
