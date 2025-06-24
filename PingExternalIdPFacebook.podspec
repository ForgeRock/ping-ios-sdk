#
# Be sure to run `pod lib lint PingExternalIdPFacebook.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPFacebook'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Facebook login integration for the Ping Identity iOS SDK'
  s.description      = <<-DESC
PingExternalIdPFacebook enables Facebook login integration within apps using the Ping Identity iOS SDK. Built on PingExternalIdP, it leverages FBSDKLoginKit to provide a seamless authentication experience using Facebook credentials. This module handles token exchange and user session management in conjunction with Ping's authentication flows.
  DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/develop/ExternalIdPFacebook/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternalIdPFacebook'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "ExternalIdPFacebook/ExternalIdPFacebook"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingExternalIdP', '~> 1.2.0-beta1'
  s.ios.dependency 'FBSDKLoginKit', '~> 16.3.1'
    
end
