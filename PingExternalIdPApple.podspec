#
# Be sure to run `pod lib lint PingExternalIdPApple.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPApple'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Sign in with Apple integration for the Ping Identity iOS SDK'
  s.description      = <<-DESC
PingExternalIdPApple adds support for Sign in with Apple to the Ping Identity iOS SDK. It builds on PingExternalIdP to provide a streamlined interface for authenticating users with their Apple ID. This module ensures secure authorization and token exchange workflows specific to Apple's authentication service.
DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/develop/ExternalIdPApple/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

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

  s.ios.dependency 'PingExternalIdP', '~> 1.2.0-beta1'
    
end
