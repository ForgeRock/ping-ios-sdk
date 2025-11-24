Pod::Spec.new do |s|
  s.name             = 'PingProtect'
  s.version          = '1.3.1'
  s.summary          = 'PingProtect SDK for iOS'
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingProtect'
  s.swift_versions = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "Protect/Protect"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Protect' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingDavinciPlugin', '~> 1.0'
  s.static_framework = true
  s.dependency 'PingOneSignals', '~> 5.3.0'
end
