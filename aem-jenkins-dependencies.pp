# Install Latest Packer
include ::packer

class puppetdeps {
	package { 'librarian-puppet':
	  ensure => 'installed',
	  provider => 'gem',
	}
}

class jsonupdater (
  $plugin_path = 'https://github.com/cliffano/packer-post-processor-json-updater/releases/download/v1.1/packer-post-processor-json-updater_linux_amd64',
  $plugin_filename = 'packer-post-processor-json-updater_linux_amd64',
) {
	archive { "/usr/local/bin/${plugin_filename}":
	  ensure => present,
	  source => $plugin_path,
	}
}

class { 'jsonupdater': }
class { 'puppetdeps': }