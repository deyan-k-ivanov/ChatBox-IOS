# Uncomment the next line to define a global platform for your project
platform :ios, '16.0'

target 'ChatBox' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Add the pod for Firebase Cloud Messaging
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'

  # Add Facebook SDK pods - LATEST version with privacy manifest
  pod 'FBSDKCoreKit', '~> 17.0.0'
  pod 'FBSDKLoginKit', '~> 17.0.0'
  

end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end

