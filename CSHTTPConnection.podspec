Pod::Spec.new do |s|
  s.name         = "CSHTTPConnection"
  s.version      = "0.0.1"
  s.summary      = "CSHTTPConnection."
  s.homepage     = "https://github.com/111minutes/CSHTTPConnection"
  s.license      = { :type => 'Custom', :text => 'Copyright (C) 2013 111minutes. All Rights Reserved.' }
  s.author       = { "TheSooth" => "thesooth@aol.com" }
  s.source       = { :git => "https://github.com/111minutes/CSHTTPConnection.git", :tag => "0.0.1" }
  s.platform     = :ios, '5.0'
  s.source_files = 'CSHTTPConnection', 'CSHTTP/**/*.{h,m}'
  s.framework  = 'CFNetwork'
  s.requires_arc = true
end

