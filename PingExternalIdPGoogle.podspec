#
# Be sure to run `pod lib lint PingExternalIdPGoogle.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdPGoogle'
  s.version          = '1.3.0'
  s.summary          = 'PingExternalIdPGoogle module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingExternalIdPGoogle module for the Ping iOS SDK is a library for Authentication with external IDP Google when using the Ping iOS SDK.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
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

  s.ios.dependency 'PingExternalIdP', '~> 1.3.0'
  s.ios.dependency 'GoogleSignIn', '~> 9.0.0'
    
end
