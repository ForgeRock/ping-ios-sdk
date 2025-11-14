#
# Be sure to run `pod lib lint PingJourney.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingJourney'
  s.version          = '1.3.1'
  s.summary          = 'PingJourney SDK for iOS'
  s.description      = <<-DESC
  The PingJourney SDK provides journey-based authentication flow management with callback handling.
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

  s.ios.deployment_target = '13.0'

  base_dir = "Journey/Journey"
  s.source_files = base_dir + '/**/*.swift'
  s.resource_bundles = {
    'PingJourney' => [base_dir + '/PrivacyInfo.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
end
