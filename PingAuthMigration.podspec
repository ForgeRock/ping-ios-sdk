Pod::Spec.new do |s|
  s.name             = 'PingAuthMigration'
  s.version          = '2.1.0'
  s.summary          = 'PingAuthMigration SDK for iOS'
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingAuthMigration'
  s.swift_versions = ['5.0', '5.1', '6.0']
  s.ios.deployment_target = '16.0'

  base_dir = "AuthMigration/AuthMigration"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'AuthMigration' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOath', '~> 2.1.0'
  s.ios.dependency 'PingPush', '~> 2.1.0'
end
