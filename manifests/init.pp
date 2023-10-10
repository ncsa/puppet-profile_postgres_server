# @summary Install and manage Postgres server and related dependencies.
#
# Install and manage Postgres server and related dependencies.
#
# @param client_ips
#   IP addresses which should be allowed to connect to Postgres services. Can take
#   any of the following forms:
#     - 'any' - this will create an allow rule with NO specified source (allow from anywhere)
#     - <IP>-<IP> - a range of IP addresses
#     - <IP> - a single IP address or CIDR definition
#
# @param cron_groups
#   Groups which should be able to schedule crons on this server (e.g., backups, exports).
#
# @param cron_users
#   Users which should be able to schedule crons on this server.
#
# @param crons
#   Raw data for Puppet cron resources.
#
# @param groups
#   Data for local group resources to create.
#
# @param other_dependencies
#   Other Puppet resources (must be defined elsewhere) that should be ensured
#   prior to installing and starting Postgres/runnings crons.
#
# @param packages
#   List of packages that must be installed.
#
# @param ports
#   An array containing that must be opened.
#
# @param services
#   List of services to start/enable.
#
# @param symlinks
#   List of symlinks to enforce (that may assist by pointing to resources that are
#   in non-standard locations, e.g., for pgBackRest). Hash of raw data for file
#   resources (that are configured to be symlinks by default).
#
# @param sysctl_settings
#   Hash of sysctl settings.
#
# @param users
#   Data for local user resources to create.
#
# @param yum_repos
#   Raw data for yumrepo resources to create.
#
# @param server_params
#   Data to pass to class 'postgresql::server'.
#   Must be a hash with at least the key: postgres_password
#   See also:
#   https://github.com/puppetlabs/puppetlabs-postgresql/blob/main/manifests/server.pp
#
# @param databases
#   Data to create databases
#   Format is Hash, as follows:
# ```
# DBNAME:
#   db_params: Hash of data valid for postgresql::server::database
#   role_name "username"
#   role_password "encrypted password"
#   role_params:
#     <data suitable for postgresql::server::role>
#   schema: "schema name"
# ```
#   See also: https://github.com/puppetlabs/puppetlabs-postgresql/
#
# @example
#   include profile_postgres_server
class profile_postgres_server (

  Array[String]  $client_ips,
  Array[String]  $cron_groups,
  Array[String]  $cron_users,
  Hash           $crons,
  Hash           $groups,
  Array[String]  $other_dependencies,
  Array[String]  $packages,
  Array[Integer] $ports,
  Array[String]  $services,
  Hash           $symlinks,
  Hash           $sysctl_settings,
  Hash           $users,
  Hash           $yum_repos,
  Hash           $server_params,
  Hash           $databases,

) {
  # Set Ad-hoc sysctl settings
  $sysctl_settings.each | $name, $params | {
    sysctl { $name:
      * => $params,
    }
  }

  # Manage local groups
  $groups.each | $name, $data | {
    group { $name:
      * => $data,
    }
  }

  # Manage local users
  $users.each | $name, $data | {
    user { $name:
      * => $data,
    }
  }

  # Manage yum repos
  $yum_repo_defaults = {
    ensure  => present,
    enabled => true,
  }
  ensure_resources( 'yumrepo', $yum_repos, $yum_repo_defaults )

  # Install packages
  $package_defaults = {
    require => $other_dependencies,
  }
  ensure_packages( $packages, $package_defaults )

  # Manage firewall
  ## firewall defaults
  Firewall {
    action => 'accept',
    proto  => 'tcp',
  }
  ## apply rules
  $client_ips.each | $index, $ips | {
    if $ips == 'any' {
      firewall { "520 allow connections on Postgres client port from anywhere (${index})":
        dport  => $ports,
      }
    } elsif '-' in $ips {
      firewall { "520 allow connections on Postgres client port from range (${ips})":
        dport     => $ports,
        src_range => $ips,
      }
    } else {
      firewall { "520 allow connections on Postgres client port from IP (${ips})":
        dport  => $ports,
        source => $ips,
      }
    }
  }

  # Manage symlinks
  File {
    ensure => 'link',
    links  => 'manage',
  }

  $symlinks.each | $location, $data | {
    file { $location:
      * => $data,
    }
  }

  # Manage services
  Service {
    ensure   => 'running',
    enable   => true,
    provider => 'systemd',
    require  => $other_dependencies,
  }
  $services.each | $svcname | {
    service { $svcname: }
  }

  # Ensure crons

  ## ensure access.conf is configured correctly: adapted from profile_ssh::allow_from
  $cron_groups.each |String $group| {
    pam_access::entry { "Allow group ${group} to execute cron tasks (profile_postgres_server)":
      group      => $group,
      origin     => 'cron crond LOCAL',
      permission => '+',
      position   => '-1',
    }
  }

  $cron_users.each |String $user| {
    pam_access::entry { "Allow user ${user} to execute cron tasks (profile_postgres_server)":
      user       => $user,
      origin     => 'cron crond LOCAL',
      permission => '+',
      position   => '-1',
    }
  }

  Cron {
    environment => ['SHELL=/bin/sh',],
    require     => $other_dependencies,
  }
  $crons.each | $k, $v | {
    cron { $k: * => $v }
  }

  ### Setup databases and users/roles
  if $server_params =~ Hash[String, Data, 1] {
    class { 'postgresql::server':
      * => $server_params,
    }
    $databases.each | $dn_name, $v | {
      postgresql::server::database {
        $db_name:
          * => $v['db_params'],
          ;
        default:
          encoding =>  'UNICODE',
          ;
      }
      $pwdhash = postgresql::postgresql_password( $v['role_name'], $v['role_password'] )
      postgresql::server::role {
        $v['role_name'] :
          password_hash => $pwdhash,
          db            => $db_name,
          *             => $v['role_params'],
          ;
        default:
          superuser     => true,
          ;
      }
      postgresql::server::grant { $db_name :
        privilege => 'ALL',
        db        => $db_name,
        role      =>  $v['role_name'],
      }
      postgresql::server::schema { $v['schema']:
        db => $db_name,
      }
    }
  }
}
