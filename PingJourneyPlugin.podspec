Pod::Spec.new do |s|
  s.name             = 'PingJourneyPlugin'
  s.version          = '1.3.1'
  s.summary          = 'Journey Plugin for PingJourney SDK'
  s.description      = <<-DESC
    The PingJourneyPlugin provides plugin functionality for the PingJourney SDK.
  DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
    :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
    :tag => s.version.to_s
  }

  s.module_name      = 'PingJourneyPlugin'
  s.swift_versions   = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "JourneyPlugin"
  s.source_files = base_dir + '/JourneyPlugin/PingJourneyPlugin/**/*.swift'
  s.resource_bundles = {
    'PingJourneyPlugin' => [base_dir + '/JourneyPlugin/PingJourneyPlugin/*.xcprivacy']
  }
  
  s.dependency 'PingOrchestrate', '~> 1.3.1'
end
