#
# Be sure to run `pod lib lint PingReCaptchaEnterprise.podspec` to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingReCaptchaEnterprise'
  s.version          = '1.2.0'
  s.summary          = 'PingReCaptchaEnterprise module for the Ping iOS SDK'
  s.description      = <<-DESC
  The PingReCaptchaEnterprise module for the Ping iOS SDK provides seamless integration with Google reCAPTCHA Enterprise.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingReCaptchaEnterprise'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "ReCaptchaEnterprise/ReCaptchaEnterprise"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'PingReCaptchaEnterprise' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingJourney', '~> 1.2.0'
  s.ios.dependency 'RecaptchaEnterprise', '~> 18.8.1'
  
end
