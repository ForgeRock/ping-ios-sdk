Pod::Spec.new do |s|
  s.name             = 'PingDavinciPlugin'
  s.version          = '2.0.0'
  s.summary          = 'Davinci Plugin for PingDavinci SDK'
  s.description      = <<-DESC
    The PingDavinciPlugin provides plugin functionality for the PingDavinci SDK.
  DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
    :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
    :tag => s.version.to_s
  }

  s.module_name      = 'PingDavinciPlugin'
  s.swift_versions   = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "DavinciPlugin/DavinciPlugin"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'DavinciPlugin' => [base_dir + '/*.xcprivacy']
  }
  
  s.dependency 'PingOrchestrate', '~> 2.0.0'
end
