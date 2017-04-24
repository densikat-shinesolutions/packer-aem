require 'spec_helper'

version = @hiera.lookup('jdk_oracle::version', nil, @scope)
version_update = @hiera.lookup('jdk_oracle::version_update', nil, @scope)

java_version = "1.#{version}.0_#{version_update}"

describe command('java -version') do
  its(:stderr) { should match /java version \"1.7/ }
  it { should return_exit_status 0 }
end
