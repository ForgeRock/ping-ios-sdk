#
# Be sure to run `pod lib lint PingProtect.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingOneProtect'
  s.version          = '1.3.0'
  s.summary          = 'PingProtect module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingProtect module for the Ping iOS SDK is a library designed to seamlessly integrate Ping Identity's Protect service into your mobile applications..
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'
  s.static_framework = true

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingOneProtect'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Protect/Protect"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Protect' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingDavinci', '~> 1.3.0'
  s.ios.dependency 'PingOneSignals', '~> 5.3.0'

end
