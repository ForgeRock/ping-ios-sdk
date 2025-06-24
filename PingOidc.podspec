#
# Be sure to run `pod lib lint PingOidc.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingOidc'
  s.version          = '1.2.0-beta1'
  s.summary          = 'OIDC client SDK for integrating PingOne and ForgeRock authentication on iOS'
  s.description      = <<-DESC
PingOidc provides a complete OpenID Connect (OIDC) client for authenticating users via the PingOne and ForgeRock identity platforms.
It supports token handling, secure redirect flows, and PKCE, and integrates with PingOrchestrate to enable full authentication journeys in native iOS apps.
DESC
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/master/Oidc/README.md'
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingOidc'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Oidc/Oidc"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Oidc' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.2.0-beta1'
end
