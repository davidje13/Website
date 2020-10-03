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

- AMI: ami-03ec287fa560a6ccc (Ubuntu 20.04, Arm)
- T4g.micro
- "Credit specification": "Unlimited" off
- 8GB HDD, encryption enabled (using alias/aws/ebs)
- Use a security group which allows inbound traffic on:
  - 80 (public: 0.0.0.0/0 & ::/0)
  - 443 (public: 0.0.0.0/0 & ::/0)
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

Note: The CloudWatch web UI seems to have a few bugs; you may need to check the alarms were created correctly (particularly whether they include the chosen action). It may not be possible to create the "recover" action (https://forums.aws.amazon.com/thread.jspa?threadID=329133)

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

## Post Setup

You should add the root domain to the
[HSTS preload list](https://hstspreload.org)
