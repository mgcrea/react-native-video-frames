require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNVideoFrames"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "14.0" }
  s.source       = { :git => ".git", :tag => "#{s.version}" }

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
  }

  s.source_files = "ios/**/*.{m,mm,cpp,swift}"
  s.private_header_files = "ios/**/*.h"

  install_modules_dependencies(s)
end
