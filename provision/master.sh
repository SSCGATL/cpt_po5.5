#!/bin/bash

# Clean the yum cache
rm -fr /var/cache/yum/*
/usr/bin/yum clean all

# Install Puppet Labs Official Repository for CentOS 7
/bin/rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm

# Install Puppet Server Components and Support Packages
/usr/bin/yum -y install puppetserver

# Start and Enable the Puppet Master
/sbin/service puppetserver start
/sbin/chkconfig puppetserver on

# Install Git
/usr/bin/yum -y install git

# Configure the Puppet Master
cat > /var/tmp/configure_puppet_master.pp << EOF
  #####                   #####
  ## Configure Puppet Master ##
  #####                   #####

cat >>/etc/puppetlabs/puppet/puppet.conf << EOF
[agent]
server=master.puppet.vm
certname=master.puppet.vm
EOF

# Bounce the network to trade out the Virtualbox IP
/sbin/service network restart

# Turn off the Firewall for this infrastructure
/sbin/service iptables stop
/sbin/service ip6tables stop
/sbin/chkconfig iptables off
/sbin/chkconfig ip6tables off

# Do initial Puppet Run
/opt/puppetlabs/puppet/bin/puppet agent -t --server=master.puppet.vm

# Place the r10k configuration file
cat > /var/tmp/configure_r10k.pp << 'EOF'
class { 'r10k':
  version => '3.1.1',
  sources => {
    'puppet' => {
      'remote'  => 'https://github.com/SSCGATL/wp_control-repo.git',
      'basedir' => "${::settings::codedir}/environments",
      'prefix'  => false,
    }
  },
  manage_modulepath => false,
}
EOF

# Install Puppet-r10k to configure r10k and all Dependencies
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-r10k
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-make
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-concat
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-stdlib
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-ruby
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-gcc
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-make
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-inifile
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-vcsrepo
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-pe_gem
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-git
/opt/puppetlabs/puppet/bin/puppet module install -f gentoo-portage

# Now Apply Subsystem Configuration
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_r10k.pp

# Install and Configure autosign.conf for agents
cat > /etc/puppetlabs/puppet/autosign.conf << 'EOF'
*.puppet.vm
EOF

# Initial r10k Deploy
/usr/bin/r10k deploy environment -pv
