# profile_postgres_server

![pdk-validate](https://github.com/ncsa/puppet-profile_postgres_server/workflows/pdk-validate/badge.svg)
![yamllint](https://github.com/ncsa/puppet-profile_postgres_server/workflows/yamllint/badge.svg)

NCSA Common Puppet Profiles - install and configure dependencies and packages for a Postgres server


## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage](#usage)
1. [Dependencies](#dependencies)
1. [Reference](#reference)


## Description

This puppet profile installs and configures dependencies and packages needed for a Postgres server.


## Setup

Include profile_postgres_server in a Puppet role or profile:
```
include ::profile_postgres_server
```


# Usage

The following parameters likely need to be set for any deployment:

packages vary by distribution and OS, so if you want Puppet to install them you must list them:
```yaml
profile_postgres_server::packages:
  - "pgbackrest"
  - "postgresql14"
  - "postgresql14-contrib"
  - "postgresql14-libs"
  - "postgresql14-server"
  - "python3-psycopg2"
```

if you need Puppet to define the Yum repo(s) Postgres will be installed from:
```yaml
profile_postgres_server::yum_repos:
  "pgdg-common":
    descr: "pgdg-common"
    baseurl: "http://server.com/path/to/pgdg-common/repo"
    skip_if_unavailable: true
    gpgcheck: true
    gpgkey: "http://server.com/path/to/pgdg_gpg_key"
    repo_gpgcheck: false
  "pgdg14":
    descr: "pgdg14"
    baseurl: "http://server.com/path/to/pgdg14/repo"
    skip_if_unavailable: true
    gpgcheck: true
    gpgkey: "http://server.com/path/to/pgdg_gpg_key"
    repo_gpgcheck: false
```

NOTE: if you are trying to install from a non-RHEL source, you'll want to disable the RHEL DNF module:
```yaml
profile_additional_packages::pkg_list:
  "RedHat":
    "postgresql":
      ensure: "disabled"
      provider: "dnfmodule"
```

if you want to install from a non-default RHEL DNF module you should be able to enable it in a similar fashion,
e.g., to enable the postgresql v12 module:
```yaml
profile_additional_packages::pkg_list:
  "RedHat":
    "postgresql:12":             
      ensure: "enabled"
      provider: "dnfmodule"
```

if you want Puppet to start and enable the service:
```yaml
profile_postgres_server::services:
  - "postgresql-14"
```

if the DB service needs to be externally accessible:
```yaml
profile_postgres_server::client_ips:
  - "172.0.0.64/26"        # specify a CIDR range or single IP
  - "172.1.0.2-172.1.0.4"  # specify an IP range
  - "any"                  # add an iptables rule w/o a source (allow from anywhere)
```

if there are Puppet resources from other profile/modules that must be ensured prior to installing/starting Postgres:
```yaml
profile_postgres_server::other_dependencies:
  - "Lvm::Logical_volume[data]"
  - "Mount[/var/lib/pgsql]"
```

if you want Puppet to manage any crons (e.g., for backups):
```yaml
profile_postgres_server::cron_groups:
  - "postgres"
## and/or
profile_postgres_server::cron_users:
  - "postgres"

## AND

profile_postgres_server::crons:
  "cron-command":
    command: "/path/to/cron-command"
    environment:
      - "SHELL=/bin/sh"
    hour: 1
    minute: 5
    month: "*"
    monthday: "*"
    weekday: "*"
    user: "postgres"
```

if you need to manage any symlinks, e.g., for pgBackRest:
```yaml
profile_postgres_server::symlinks:
  "/etc/pgbackrest.conf":
    target: "/data/pg-backups/pgbackrest.conf.d/pgbackrest.conf"
```

## Depencencies

[herculesteam/augeasproviders_sysctl](https://forge.puppet.com/modules/herculesteam/augeasproviders_sysctl) Puppet module


## Reference

See: [REFERENCE.md](REFERENCE.md)
