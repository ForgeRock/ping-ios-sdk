Pod::Spec.new do |s|
  s.name             = 'PingBinding'
  s.version          = '1.3.1'
  s.summary          = 'PingBinding SDK for iOS'
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingBinding'
  s.swift_versions = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "Binding/Binding"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Binding' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
  s.ios.dependency 'PingOidc', '~> 1.3.1'
  s.ios.dependency 'PingJourneyPlugin', '~> 1.3.1'
  s.ios.dependency 'PingMfaCommons', '~> 1.3.1'
  s.ios.dependency 'PingStorage', '~> 1.3.1'
  s.ios.dependency 'PingLogger', '~> 1.3.1'
end
