#
# Be sure to run `pod lib lint PingDeviceId.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingDeviceId'
  s.version          = '2.1.0'
  s.summary          = 'PingDeviceId module for the Ping iOS SDK'
  s.description      = <<-DESC
  The Device ID module for Swift provides a robust and secure method for generating and managing a unique identifier for a device.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingDeviceId'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "DeviceId/DeviceId"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'DeviceId' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingLogger', '~> 2.1.0'
  s.ios.dependency 'PingStorage', '~> 2.1.0'
    
end
