#
# Be sure to run `pod lib lint PingExternalIdPFacebook.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPFacebook'
  s.version          = '1.3.1'
  s.summary          = 'PingExternalIdPFacebook module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingExternalIdPFacebook module for the Ping iOS SDK is a library for Authentication with external IDP Facebook when using the Ping iOS SDK.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternalIdPFacebook'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "ExternalIdPFacebook/ExternalIdPFacebook"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingExternalIdP', '~> 1.3.1'
  s.ios.dependency 'FBSDKLoginKit', '~> 16.3.1'
    
end
