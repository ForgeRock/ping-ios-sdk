#
# Be sure to run `pod lib lint PingDeviceProfile.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingDeviceProfile'
  s.version          = '1.2.0'
  s.summary          = 'PingDeviceProfile SDK for iOS'
  s.description      = <<-DESC
  The PingDeviceProfile module for the Ping iOS SDK is a library designed to provide a structured framework for collecting device information in iOS applications.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingDeviceProfile'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "DeviceProfile/DeviceProfile"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'DeviceProfile' => [base_dir + '/*.xcprivacy']
  }
  
    s.ios.dependency 'PingJourney', '~> 1.2.0'
    s.ios.dependency 'PingTamperDetector', '~> 1.2.0'
    s.ios.dependency 'PingLogger', '~> 1.2.0''
end
