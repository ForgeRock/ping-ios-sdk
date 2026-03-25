#
# Be sure to run `pod lib lint PingOath.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingOath'
  s.version          = '2.0.0'
  s.summary          = 'PingOath module for the Ping iOS SDK'
  s.description      = <<-DESC
  PingOath is a comprehensive iOS SDK module that provides One-Time Password (OTP) authentication functionality, including support for both TOTP (Time-based One-Time Password) and HOTP (HMAC-based One-Time Password) authentication mechanisms following RFC 4226 and RFC 6238 standards.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingOath'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "Oath/Oath"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Oath' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingTamperDetector', '~> 2.0.0'
    
end
