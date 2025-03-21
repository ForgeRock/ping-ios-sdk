#
# Be sure to run `pod lib lint External-idp.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'External-idp'
  s.version          = '1.0.0'
  s.summary          = 'External-idp module for the Ping iOS SDK'
  s.description      = <<-DESC
  The External-idp module for the Ping iOS SDK is a library for Authentication with external IDPs when using the Ping iOS SDK.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'External_idp'
  s.swift_versions = ['5.0', '5.1']

  s.ios.deployment_target = '13.0'

  base_dir = "External-idp/External-idp"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingDavinci', '~> 1.0.0'
  s.ios.dependency 'PingBrowser', '~> 1.0.0'
  s.ios.dependency 'FBSDKLoginKit', '~> 16.3.1'
  s.ios.dependency 'GoogleSignIn', '~> 8.1.0-vwg-eap-1.0.0'
    
end
