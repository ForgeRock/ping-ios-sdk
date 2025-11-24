Pod::Spec.new do |s|
  s.name             = 'PingReCaptchaEnterprise'
  s.version          = '1.3.1'
  s.summary          = 'PingReCaptchaEnterprise SDK for iOS'
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
    'ReCaptchaEnterprise' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingJourneyPlugin', '~> 1.0'
  s.ios.dependency 'PingLogger', '~> 1.3.1'
  
  s.dependency 'RecaptchaEnterprise', '~> 18.8.1'
end
