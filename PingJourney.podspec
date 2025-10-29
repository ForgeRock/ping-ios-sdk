#
# Be sure to run `pod lib lint PingJourney.podspec` to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged.
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingJourney'
  s.version          = '1.3.0-beta2'
  s.summary          = 'PingJourney SDK for iOS'
  s.description      = <<-DESC
  The PingJourney SDK provides APIs to orchestrate authentication journeys using the Ping Identity platform.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name      = 'PingJourney'
  s.swift_versions   = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  # Base directory for source files
  base_dir = 'Journey/Journey'
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Journey' => [base_dir + '/*.xcprivacy']
  }

  # Dependencies
  s.ios.dependency 'PingOidc', '~> 1.3.0-beta2'
  s.ios.dependency 'PingLogger', '~> 1.3.0-beta2'
  s.ios.dependency 'PingOrchestrate', '~> 1.3.0-beta2'
  s.ios.dependency 'PingStorage', '~> 1.3.0-beta2'
end
