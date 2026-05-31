#
# Be sure to run `pod lib lint PingFido.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingFido'
  s.version          = '2.0.0'
  s.summary          = 'PingFido module for the Ping iOS SDK'
  s.description      = <<-DESC
    PingFido module for the Ping iOS SDK
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingFido'
  s.swift_versions = ['5.0', '5.1', '6.0']

  s.ios.deployment_target = '16.0'

  base_dir = "Fido/Fido"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Fido' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingLogger', '~> 2.0.0'
  s.ios.dependency 'PingCommons', '~> 2.0.0'
  s.ios.dependency 'PingDavinciPlugin', '~> 2.0.0'
  s.ios.dependency 'PingJourneyPlugin', '~> 2.0.0'
end
