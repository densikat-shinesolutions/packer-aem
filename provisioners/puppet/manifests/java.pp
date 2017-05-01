  # Manipulates alternatives using update-alternatives.
  # Supports RHEL, Centos and Suse.
  # Ubuntu not tested (yet).
  #
  # There is rudimentary alternatives support in the java class,
  # but it's rather limited and doesn't support most platforms and java versions.
  define alternatives_update (
    $item = $title,   # the item to manage, ie "java"
    $versiongrep,     # string to pass to grep to select an alternative, ie '1.8'
    $optional = true,  # if false, execution will fail if the version is not found
    $altcmd   = 'update-alternatives' # command to use
  ) {

    if ! $optional {
      # verify that we have exactly 1 matching alternatives, unless it's optional
      exec { "check alternatives for ${item}":
        path    => ['/sbin','/bin','/usr/bin','/usr/sbin'],
        command => "echo Alternative for ${item} version containing ${versiongrep} was not found, or multiple found ; false",
        unless  => "test $(${altcmd} --display ${item} | grep '^/' | grep -w -- $versiongrep | wc -l) -eq 1",
        before  => Exec["update alternatives for ${item} to ${versiongrep}"],
      }
    }

    # Runs the update alternatives command
    #  - unless it reports that it's already set to that version
    #  - unless that version is not found via grep
    exec { "update alternatives for ${item} to ${versiongrep}":
      path    => ['/sbin','/bin','/usr/bin','/usr/sbin'],
      command => "${altcmd} --set ${item} $( ${altcmd} --display ${item} | grep '^/' | grep -w -- $versiongrep | sed 's/ .*$//' ) ",
      unless  => "${altcmd} --display ${item} | grep 'currently points' | grep -w -- $versiongrep ",
      onlyif  => "${altcmd} --display ${item} | grep '^/' | grep -w -- $versiongrep", # check that there is one (if optional and not found, this won't run)
    }

  }

class java (
  $tmp_dir,
  $aem_cert_source,
  $install_collectd = true,
  $collectd_cloudwatch_source_url = 'https://github.com/awslabs/collectd-cloudwatch/archive/master.tar.gz',
) {

  stage { 'test':
    require => Stage['main'],
  }

  class { '::oracle_java':
    version         => '8u121',
    type            => 'jdk',
    add_alternative => true,
  }


  file { '/etc/ld.so.conf.d/99-libjvm.conf':
    ensure  => file,
    content => "/usr/java/latest/jre/lib/amd64/server\n",
    notify  => Exec['/sbin/ldconfig'],
  }

  exec { '/sbin/ldconfig':
    refreshonly => true,
  }


  archive { "${tmp_dir}/aem.cert":
    ensure => present,
    source => $aem_cert_source,
  }

  java_ks { 'Add cert to default Java truststore':
    ensure      => latest,
    name        => 'cqse',
    certificate => "${tmp_dir}/aem.cert",
    target      => '/usr/java/default/jre/lib/security/cacerts',
    password    => 'changeit',
  }

  if $install_collectd {

    $collectd_plugins = [
      'syslog', 'cpu', 'interface', 'load', 'memory',
    ]

    $collectd_jmx_types_path = '/usr/share/collectd/jmx.db'

    $collectd_cloudwatch_base_dir = '/opt/collectd-cloudwatch'

    file { '/opt/collectd-cloudwatch':
      ensure => directory,
    }

    archive { '/tmp/collectd-cloudwatch.tar.gz':
      extract       => true,
      extract_path  => $collectd_cloudwatch_base_dir,
      extract_flags => '--strip-components=1 -xvzf',
      creates       => "${collectd_cloudwatch_base_dir}/src/cloudwatch_writer.py",
      source        => $collectd_cloudwatch_source_url,
      cleanup       => true,
    }

    class { '::collectd':
      purge           => true,
      recurse         => true,
      purge_config    => true,
      minimum_version => '5.4',
      package_ensure  => latest,
      service_ensure  => stopped,
      service_enable  => false,
      typesdb         => [
        '/usr/share/collectd/types.db',
        $collectd_jmx_types_path,
      ],
    }

    file { $collectd_jmx_types_path:
      ensure  => file,
      content => file('config/collectd_jmx_types.db'),
      require => Package[$::collectd::install::package_name],
    }

    collectd::plugin { $collectd_plugins:
      ensure => present,
    }

    class { '::collectd::plugin::python':
      modulepaths => [
        '/usr/lib/python2.7/dist-packages',
        '/usr/lib/python2.7/site-packages',
        "${collectd_cloudwatch_base_dir}/src",
      ],
      logtraces   => true,
    }


    collectd::plugin::python::module {'cloudwatch_writer':
      script_source => 'puppet:///modules/config/cloudwatch_writer.py',
    }

    $cloudwatch_memory_stats = [
      'used', 'buffered', 'cached', 'free',
    ]

    $cloudwatch_memory_stats.each |$stat| {
      file_line { "${stat} memory":
        ensure  => present,
        line    => "memory--memory-${stat}",
        path    => "${collectd_cloudwatch_base_dir}/src/cloudwatch/config/whitelist.conf",
        require => Collectd::Plugin::Python::Module['cloudwatch_writer'],
      }
    }

    collectd::plugin::genericjmx::mbean {
      'garbage_collector':
        object_name     => 'java.lang:type=GarbageCollector,*',
        instance_prefix => 'gc-',
        instance_from   => 'name',
        values          => [
          {
            type      => 'invocations',
            table     => false,
            attribute => 'CollectionCount',
          },
          {
            type            => 'total_time_in_ms',
            instance_prefix => 'collection_time',
            table           => false,
            attribute       => 'CollectionTime',
          },
        ];
      'memory-heap':
        object_name     => 'java.lang:type=Memory',
        instance_prefix => 'memory-heap',
        values          => [
          {
            type      => 'jmx_memory',
            table     => true,
            attribute => 'HeapMemoryUsage',
          },
        ];
      'memory-nonheap':
        object_name     => 'java.lang:type=Memory',
        instance_prefix => 'memory-nonheap',
        values          => [
          {
            type      => 'jmx_memory',
            table     => true,
            attribute => 'NonHeapMemoryUsage',
          },
        ];
      'memory-permgen':
        object_name     => 'java.lang:type=MemoryPool,name=*Perm Gen',
        instance_prefix => 'memory-permgen',
        values          => [
          {
            type      => 'jmx_memory',
            table     => true,
            attribute => 'Usage',
          },
        ];
    }

  }

  alternatives_update { 'java': versiongrep => 'jdk1.8.0_121/bin/java' }

  class { 'serverspec':
    stage             => 'test',
    component         => 'java',
    staging_directory => "${tmp_dir}/packer-puppet-masterless-java",
    tries             => 5,
    try_sleep         => 3,
  }

}

include java
