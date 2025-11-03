#
# Be sure to run `pod lib lint PingExternalIdPApple.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPApple'
  s.version          = '1.3.0-beta3'
  s.summary          = 'PingExternalIdPApple module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingExternalIdPApple module for the Ping iOS SDK is a library for Authentication with external IDP Apple when using the Ping iOS SDK.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternalIdPApple'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "ExternalIdPApple/ExternalIdPApple"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingExternalIdP', '~> 1.3.0-beta3'
    
end
