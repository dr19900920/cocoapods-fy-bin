

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-fy-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-fy-bin/helpers/framework_builder'
require 'cocoapods-fy-bin/helpers/library_builder'
require 'cocoapods-fy-bin/helpers/sources_helper'
require 'cocoapods-fy-bin/command/bin/spec/push'

module CBin
  class Upload
    class Helper
      include CBin::SourcesHelper

      def initialize(spec,code_dependencies,sources)
        @spec = spec
        @code_dependencies = code_dependencies
        @sources = sources
        @remote_helper = RemoteHelper.new()
      end

      def upload
        del_zip
        Dir.chdir(CBin::Config::Builder.instance.root_dir) do
          # 创建binary-template.podsepc
          # 上传二进制文件
          # 上传二进制 podspec
          res_zip = curl_zip
          if res_zip
            filename = spec_creator
            push_binary_repo(filename)
          end
          res_zip
        end
      end

      def spec_creator
        spec_creator = CBin::SpecificationSource::Creator.new(@spec)
        spec_creator.create
        spec_creator.write_spec_file
        spec_creator.filename
      end

      # 如果存在相同的版本号先删除组件二进制
      def del_zip
        print <<EOF
          删除已上传的二进制文件 #{@spec.name} #{@spec.version} #{CBin.config.configuration_env}
EOF
        result = @remote_helper.exist?(@spec.name, @spec.version, CBin.config.configuration_env)
        if result
          print <<EOF
          删除中
EOF
          @remote_helper.delete(@spec.name, @spec.version, CBin.config.configuration_env)
        end
      end

      #推送二进制
      def curl_zip
        zip_file = "#{CBin::Config::Builder.instance.library_file(@spec)}.zip"
        res = File.exist?(zip_file)
        unless res
          zip_file = CBin::Config::Builder.instance.framework_zip_file(@spec) + ".zip"
          res = File.exist?(zip_file)
        end
        if res
          print <<EOF
          上传二进制文件 #{@spec.name} #{@spec.version} #{CBin.config.configuration_env}
EOF
          remote.upload(@module_name, @version, mode.downcase, zip_file) if res
        end

        res
      end


      # 上传二进制 podspec
      def push_binary_repo(binary_podsepc_json)
        argvs = [
            "#{binary_podsepc_json}",
            "--binary",
            "--sources=#{sources_option(@code_dependencies, @sources)}",
            "--skip-import-validation",
            "--use-libraries",
            "--allow-warnings",
            "--verbose",
            "--code-dependencies"
        ]
        if @verbose
          argvs += ['--verbose']
        end

        push = Pod::Command::Bin::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.validate!
        push.run
      end

    end
  end
end
