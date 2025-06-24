#
# Be sure to run `pod lib lint PingDavinci.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingDavinci'
  s.version          = '1.2.0-beta1'
  s.summary          = 'iOS SDK for building authentication flows using PingOne DaVinci'
  s.description = <<-DESC
PingDavinci is a powerful iOS SDK that enables developers to build and manage flexible authentication and authorization flows using PingOne DaVinci and ForgeRock Journeys. It offers a simple state-based API to navigate authentication steps, handle user interactions, and manage session states securely. Designed to integrate with PingOidc and other Ping SDKs, it provides an extensible architecture for modern mobile identity experiences.
DESC
  s.homepage          = 'https://github.com/ForgeRock/ping-ios-sdk'
  s.documentation_url = 'https://github.com/ForgeRock/ping-ios-sdk/blob/main/Davinci/README.md'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = 'Ping Identity'
  s.source            = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingDavinci'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Davinci/Davinci"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Davinci' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOidc', '~> 1.2.0-beta1'
    
end
