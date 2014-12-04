node default {

  package { ['vim', 'htop', 'screen', 'tree']:
    ensure => present
  }

  $aegir_user = 'aegir'
  $aegir_root = '/var/aegir'
  $web_group  = 'www-data'

  User <| title == $aegir_user |> {
    groups +> [$web_group, 'adm'], #Allow access to logs
    shell  => '/bin/bash',
  }

  # Allow 'aegir' user password-less sudo.
  file {'/etc/sudoers.d/aegir-sudo':
    content => "${aegir_user} ALL=NOPASSWD:ALL",
    mode    => '440',
    owner   => 'root',
    group   => 'root',
  }

  file {"$aegir_root/.ssh":
    ensure  => directory,
    owner   => $aegir_user,
    group   => $aegir_user,
    require => User[$aegir_user],
  }
  file {"$aegir_root/.ssh/authorized_keys":
    ensure  => present,
    source  => '/vagrant/.valkyrie/ssh/authorized_keys',
    mode    => 600,
    owner   => $aegir_user,
    group   => $aegir_user,
    require => File["$aegir_root/.ssh"],
  }
  file {'/vagrant/.valkyrie/cache':
    ensure => directory,
  }
  file {'/vagrant/.valkyrie/cache/first_run_complete':
    ensure  => present,
    content => generate('/bin/date', '+%Y%d%m_%H:%M:%S'),
    require => [
      File["$aegir_root/.ssh/authorized_keys"],
      File['/vagrant/.valkyrie/cache'],
    ]
  }

  class {'drush::git::drush':
    #git_branch => '6.x',
    git_branch => 'master',
    before     => Class['aegir::dev'],
  }

  class { 'aegir::dev' :
    hostmaster_ref  => '7.x-3.x',
    provision_ref   => '7.x-3.x',
    make_aegir_platform  => true,
    makefile        => '/var/aegir/.drush/provision/aegir-dev.make',
    platform_path   => '/var/aegir/hostmaster-7.x-3.x',
    queued_service  => false,
  }

  if $domain == 'local' {
    include avahi
  }
  include skynet

  drush::git {'http://git.drupal.org/sandbox/ergonlogic/2386543.git':
    path       => '/var/aegir/hostmaster-7.x-3.x/profiles/hostmaster/modules/aegir',
    dir_name   => 'hosting_reinstall',
    git_branch => '7.x-3.x',
    user       => $aegir_user,
    #update     => true,
    require    => Class['aegir::dev'],
    before     => Drush::En['hosting_reinstall'],
    notify     => Drush::Run['drush-cc-drush:valkyrie'],
  }
  /*
  drush::git {'http://git.poeticsystems.com/valkyrie/hosting-storage.git':
    path       => '/var/aegir/hostmaster-7.x-3.x/profiles/hostmaster/modules/aegir',
    dir_name   => 'hosting_storage',
    #git_branch => '7.x-3.x',
    git_branch => 'master',
    user       => $aegir_user,
    #update     => true,
    require    => Class['aegir::dev'],
  }
  */

  drush::en {[
    'hosting_alias',
    'hosting_git',
    'hosting_git_pull',
    'hosting_platform_pathauto',
    'hosting_reinstall',
    #'hosting_storage',  # Not ready for default usage.
  ]:
    site_alias => '@hm',
    drush_user => $aegir_user,
    drush_home => $aegir_root,
    require    => Class['aegir::dev'],
  }

  include valkyrie::deploy_keys

  #drush::git {'git@git.poeticsystems.com:valkyrie/drush-valkyrie.git':
  drush::git {'http://git.poeticsystems.com/valkyrie/drush-valkyrie.git':
    path     => '/var/aegir/.drush',
    dir_name => 'valkyrie',
    user     => $aegir_user,
    require  => User[$aegir_user],
    notify   => Drush::Run['drush-cc-drush:valkyrie'],
  }

  drush::run {"drush-cc-drush:valkyrie":
    command     => 'cache-clear drush',
    drush_user  => $aegir_user,
    drush_home  => '/var/aegir',
    refreshonly => true,
  }

  # Ensure our git code is running on our dev branch
  #drush::git {'ergonlogic@git.drupal.org:project/hosting_git.git':
  drush::git {'http://git.drupal.org/project/hosting_git.git':
    path       => '/var/aegir/hostmaster-7.x-3.x/profiles/hostmaster/modules/aegir',
    dir_name   => 'hosting_git',
    git_branch => 'dev/2362437',
    user       => $aegir_user,
    #update     => true,
    require    => Class['aegir::dev'],
  }

  # Set a default URL alias (based on the Facter-provided $domain)
  drush::run {'drush-vset-tld':
    command    => "vset hosting_alias_subdomain ${domain}",
    site_alias => '@hm',
    drush_user => $aegir_user,
    drush_home => '/var/aegir',
    unless     => "/usr/bin/drush @hm vget hosting_alias_subdomain|/bin/grep ${domain}",
    require    => Class['aegir::dev'],
  }

  # Allow site deletion without disabling first.
  drush::run {'drush-vset-no-disable-before-delete':
    command    => "vset hosting_require_disable_before_delete 0",
    site_alias => '@hm',
    drush_user => $aegir_user,
    drush_home => '/var/aegir',
    unless     => "/usr/bin/drush @hm vget hosting_require_disable_before_delete|/bin/grep 0",
    require    => Class['aegir::dev'],
  }

}
