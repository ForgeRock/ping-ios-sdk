#
# Be sure to run `pod lib lint Logger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Logger'
  s.version          = '0.9.0-beta2'
  s.summary          = 'Logger SDK for iOS'
  s.description      = <<-DESC
  The Logger SDK provides a versatile logging interface and a set of common loggers for the Ping SDKs.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/unified-sdk-ios.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'Logger'

  s.ios.deployment_target = '13.0'

  base_dir = "Logger/Logger"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Logger' => [base_dir + '/*.xcprivacy']
  }
end
