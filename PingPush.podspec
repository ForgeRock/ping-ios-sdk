#
# Be sure to run `pod lib lint PingPush.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingPush'
  s.version          = '1.3.1'
  s.summary          = 'PingPush SDK for iOS'
  s.description      = <<-DESC
  The PingPush SDK provides Push client for PingOne and ForgeRock platform.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingPush'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "Push/Push"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Push' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
end
