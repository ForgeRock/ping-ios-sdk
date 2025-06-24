#
# Be sure to run `pod lib lint PingExternalIdPGoogle.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPGoogle'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Google Sign-In integration for the Ping Identity iOS SDK'
  s.description      = <<-DESC
PingExternalIdPGoogle enables Google Sign-In authentication in apps using the Ping Identity iOS SDK. Built on top of PingExternalIdP, it integrates the GoogleSignIn SDK and provides a seamless login experience using Google accounts. It supports token exchange and redirects within Ping-authenticated flows.
DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/develop/ExternalIdPGoogle/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source            = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternalIdPGoogle'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "ExternalIdPGoogle/ExternalIdPGoogle"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingExternalIdP', '~> 1.2.0-beta1'
  s.ios.dependency 'GoogleSignIn', '~> 8.1.0-vwg-eap-1.0.0'
    
end
