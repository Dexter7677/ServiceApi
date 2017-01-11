#
# Be sure to run `pod lib lint ServiceApi.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = 'ServiceApi'
s.version          = '1.0'
s.summary          = 'ServiceApi is Swift class for simplefy web api call using small setups'

s.description      = <<-DESC
TODO: ServiceApi is Swift class for simplefy web api call using small setups, dependancy is SwiftyJSON
DESC

s.homepage         = 'https://github.com/erbittuu/ServiceApi'
# s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
s.license          = { :type => 'MIT', :file => 'LICENSE' }
s.author           = { 'Utsav Patel' => 'utsavhacker@gmail.com' }
s.source           = { :git => 'https://github.com/erbittuu/ServiceApi.git', :tag => s.version.to_s }

s.social_media_url = 'https://twitter.com/erbittuu'

s.ios.deployment_target = '8.0'

s.source_files = 'ServiceApi/Classes/*'

s.frameworks = 'SystemConfiguration', 'MobileCoreServices'

s.dependency 'SwiftyJSON'

s.pod_target_xcconfig =  {
'SWIFT_VERSION' => '3.0',
}

end
