#
# Be sure to run `pod lib lint PingBrowser.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingBrowser'
  s.version          = '1.2.0-beta1'
  s.summary          = 'In-app browser integration module for Ping Identity iOS authentication flows'
  s.description      = <<-DESC
PingBrowser provides in-app browser support for authentication flows in Ping Identity's iOS SDK. It enables secure and seamless web-based interactions using SFSafariViewController or ASWebAuthenticationSession for login and consent flows. This module integrates with PingLogger for consistent event tracking across authentication journeys.
DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/master/Browser/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source            = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingBrowser'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Browser/Browser"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Browser' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingLogger', '~> 1.2.0-beta1'
    
end
