Pod::Spec.new do |s|
  s.name         = "DPromise"
  s.version      = "0.0.1"
  s.summary      = "Objective-C promises"
  s.description  = "chain promises with generics, and disposing"
  s.homepage     = "https://github.com/AlexanderSviridov/DPromise"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Alexander Sviridov" => "alexander_sviridov@icloud.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/AlexanderSviridov/DPromise.git", :tag => "0.0.1" }
  s.source_files = "src", "src/**/*.{h,m}"
  s.requires_arc = true
  s.dependency 'LinqToObjectiveC'
end
