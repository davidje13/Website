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
are found

# AWS Instance

## EC2

- Community AMI: ami-00035f41c82244dab (Ubuntu 18.04)
- T2.micro
- 8GB HDD (only uses ~2GB but this is the minimum)
- Use a security group which allows inbound traffic on:
  - 80 (public)
  - 443 (public)
  - 22 (your ip)
- (assign elastic IP)

## Route53

```
A   <domain>          <elastic ip>               (1day)
A   www.<domain>      <elastic ip>               (1day)
A   sequence.<domain> <elastic ip>               (1day)
CAA <domain>          0 issue "letsencrypt.org"  (1day)
```

## Installation

Once the EC2 & Route53 config is done, log in to the box and run:

```sh
git clone https://github.com/davidje13/Website.git
Website/install.sh '<domain>'
```
