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

- AMI: ami-06358f49b5839867c (Ubuntu 18.04, x86)
- T3a.micro
- "T2/T2 Unlimited" off
- 8GB HDD, encryption enabled (using alias/aws/ebs)
- Use a security group which allows inbound traffic on:
  - 80 (public: 0.0.0.0/0 & ::/0)
  - 443 (public: 0.0.0.0/0 & ::/0)
  - 22 (your ip)
- (assign elastic IP)

## CloudWatch

- "Instance Failure Restart" - Restart if instance is down for 15 minutes
  - Whenever StatusCheckFailed_Instance > 0 for 3 out of 3 datapoints
  - Missing data = missing
  - Period 5 minutes
  - When state is ALARM
    - EC2 action: Reboot instance

- "System Failure Recover" - Recover if system is down for 15 minutes
  - Whenever StatusCheckFailed_System > 0 for 3 out of 3 datapoints
  - Missing data = missing
  - Period 5 minutes
  - When state is ALARM
    - EC2 action: Recover instance

## Route53

```
A   <domain>          <elastic ip>               (1day)
A   www.<domain>      <elastic ip>               (1day)
A   retro.<domain>    <elastic ip>               (1day)
A   retros.<domain>   <elastic ip>               (1day)
A   refacto.<domain>  <elastic ip>               (1day)
A   sequence.<domain> <elastic ip>               (1day)
CAA <domain>          0 issue "letsencrypt.org"  (1day)
```

## Installation

Once the EC2 & Route53 config is done, log in to the box and run:

```sh
git clone https://github.com/davidje13/Website.git
cp env/refacto.template.env env/refacto.env

vi env/refacto.env
# fill in any appropriate options then save

Website/install.sh '<domain>'
```

## Post Setup

You should add the root domain to the
[HSTS preload list](https://hstspreload.org)
