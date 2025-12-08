#
# Be sure to run `pod lib lint PingDeviceClient.podspec` to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingDeviceClient'
  s.version          = '1.3.1'
  s.summary          = 'PingDeviceClient module for the Ping iOS SDK'
  s.description      = <<-DESC
  DeviceClient module simplifies device management operations for Ping AIC. It provides a clean, type-safe API for managing authentication devices including OATH, Push, Bound, Profile, and WebAuthn devices.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingDeviceClient'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "DeviceClient/DeviceClient"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'PingDeviceClient' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
  s.ios.dependency 'PingLogger', '~> 1.3.1'
  s.ios.dependency 'PingCommons', '~> 1.3.1'
  
end
