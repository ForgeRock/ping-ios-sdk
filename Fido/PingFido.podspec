
Pod::Spec.new do |s|
  s.name             = 'PingFido'
  s.version          = '1.3.0'
  s.summary          = 'PingFido SDK for iOS'
  s.description      = <<-DESC
  The PingFido SDK provides Fido2 functionality for PingOne and ForgeRock platform.
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

  s.ios.deployment_target = '13.0'

  s.source_files = 'Fido/Fido/**/*.swift'
  
  s.ios.dependency 'PingJourney', '~> 1.3.0'
  s.ios.dependency 'PingLogger', '~> 1.3.0'
end
