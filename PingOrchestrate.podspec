#
# Be sure to run `pod lib lint PingOrchestrate.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingOrchestrate'
  s.version          = '1.1.0'
  s.summary          = 'PingOrchestrate SDK for iOS'
  s.description      = <<-DESC
  The PingOrchestrate SDK provides a simple way to build a state machine for ForgeRock Journey and PingOne DaVinci.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingOrchestrate'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Orchestrate/Orchestrate"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Orchestrate' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingLogger', '~> 1.1.0'
  s.ios.dependency 'PingStorage', '~> 1.1.0'
end
