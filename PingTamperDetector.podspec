
#
# Be sure to run `pod lib lint PingJailbreakDetector.podspec` to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingTamperDetector'
  s.version          = '1.0.0'
  s.summary          = 'PingJailbreakDetector module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingJailbreakDetector module for the Ping iOS SDK is a library for detecting jailbroken devices.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingJailbreakDetector'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "JailbreakDetector/JailbreakDetector"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'TamperDetector' => [base_dir + '/*.xcprivacy']
  }
  
end
