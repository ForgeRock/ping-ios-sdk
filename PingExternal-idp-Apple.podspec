#
# Be sure to run `pod lib lint PingExternal-idp-Apple.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternal-idp-Apple'
  s.version          = '1.1.0'
  s.summary          = 'PingExternal-idp-Apple module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingExternal-idp-Apple module for the Ping iOS SDK is a library for Authentication with external IDP Apple when using the Ping iOS SDK.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternal_idp_Apple'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "External-idp-Apple/External-idp-Apple"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingExternal-idp', '~> 1.1.0'
    
end
