require 'cocoapods'

if Pod.match_version?('~> 1.4')
  require 'cocoapods-fy-bin/native/podfile'
  require 'cocoapods-fy-bin/native/installation_options'
  require 'cocoapods-fy-bin/native/specification'
  require 'cocoapods-fy-bin/native/path_source'
  require 'cocoapods-fy-bin/native/analyzer'
  require 'cocoapods-fy-bin/native/installer'
  require 'cocoapods-fy-bin/native/podfile_generator'
  require 'cocoapods-fy-bin/native/pod_source_installer'
  require 'cocoapods-fy-bin/native/linter'
  require 'cocoapods-fy-bin/native/resolver'
  require 'cocoapods-fy-bin/native/source'
  require 'cocoapods-fy-bin/native/validator'
  require 'cocoapods-fy-bin/native/acknowledgements'
  require 'cocoapods-fy-bin/native/sandbox_analyzer'
  require 'cocoapods-fy-bin/native/podspec_finder'
  require 'cocoapods-fy-bin/native/file_accessor'
  require 'cocoapods-fy-bin/native/pod_target_installer'
  require 'cocoapods-fy-bin/native/target_validator'

end
