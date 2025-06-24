#
# Be sure to run `pod lib lint PingExternalIdP.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingExternalIdP'
  s.version          = '1.2.0-beta1'
  s.summary          = 'Authentication module for external identity providers using Ping Identity iOS SDK'
  s.description      = <<-DESC
PingExternalIdP extends the Ping Identity iOS SDK to support authentication via external identity providers (IdPs) such as Google, Facebook, and enterprise SSO systems. It integrates with PingDavinci to provide a consistent authentication flow and uses PingBrowser for secure web-based redirection and consent handling.
DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/tree/develop/ExternalIdP/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name = 'PingExternalIdP'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "ExternalIdP/ExternalIdP"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'External-idp' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingDavinci', '~> 1.2.0-beta1'
  s.ios.dependency 'PingBrowser', '~> 1.2.0-beta1'
    
end
