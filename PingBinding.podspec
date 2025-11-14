#
# Be sure to run `pod lib lint PingBinding.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingBinding'
  s.version          = '1.3.1'
  s.summary          = 'PingBinding Module for iOS'
  s.description      = <<-DESC
  The PingBinding Module provides device binding and signing capabilities for native applications.
  Supports ES256 (ECDSA with P-256 curve) for hardware-backed secure key storage using iOS Secure Enclave.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingBinding'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '13.0'

  base_dir = "Binding/Binding"
  s.source_files = base_dir + '/**/*.swift'
  s.resource_bundles = {
    'PingBinding' => [base_dir + '/PrivacyInfo.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 1.3.1'
  s.ios.dependency 'PingOidc', '~> 1.3.1'
  s.ios.dependency 'PingJourney', '~> 1.3.1'
  s.ios.dependency 'PingMfaCommons', '~> 1.3.1'
  s.ios.dependency 'PingStorage', '~> 1.3.1'
  s.ios.dependency 'PingLogger', '~> 1.3.1'
end
