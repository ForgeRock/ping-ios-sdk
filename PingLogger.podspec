#
# Be sure to run `pod lib lint PingLogger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingLogger'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Versatile logging SDK for Ping Identity mobile frameworks on iOS'
  s.description      = <<-DESC
PingLogger is a lightweight, modular logging SDK for iOS that provides structured logging,
extensible logger types, and support for logging to multiple destinations. It is used
across Ping Identity mobile SDKs and can be integrated into custom iOS apps.
DESC
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/master/Logger/README.md'
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingLogger'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Logger/Logger"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Logger' => [base_dir + '/*.xcprivacy']
  }
end
