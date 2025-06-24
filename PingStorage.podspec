#
# Be sure to run `pod lib lint PingStorage.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingStorage'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Lightweight storage SDK for secure and modular data handling in Ping Identity iOS apps'
  s.description      = <<-DESC
PingStorage provides a flexible, modular interface for secure data storage on iOS.
It includes implementations such as in-memory, secure storage using Keychain, and file-based storage.
Designed to be used with Ping Identity SDKs, PingStorage can also be integrated into standalone iOS apps.
DESC
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/master/Storage/README.md'
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingStorage'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Storage/Storage"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Storage' => [base_dir + '/*.xcprivacy']
  }
end
