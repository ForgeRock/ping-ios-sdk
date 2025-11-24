Pod::Spec.new do |s|
  s.name             = 'PingJourney'
  s.version          = '1.3.1'
  s.summary          = 'PingJourney SDK for iOS'
  s.description      = <<-DESC
  The PingJourney SDK is a powerful and flexible library for Authentication and Authorization.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingJourney'
  s.swift_versions = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "Journey/Journey"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Journey' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingJourneyPlugin', '~> 1.0'
  s.ios.dependency 'PingOidc', '~> 1.3.1'
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
end
