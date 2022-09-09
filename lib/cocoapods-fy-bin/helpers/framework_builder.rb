# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-fy-bin/helpers/framework.rb'
require 'English'
require 'cocoapods-fy-bin/config/config_builder'
require 'shellwords'

module CBin
  class Framework
    class Builder
      include Pod
#Debug下还待完成
      def initialize(spec, file_accessor, platform, source_dir, archs, pre_build_shell, suf_build_shell, build_permission, toolchain, isRootSpec = true, build_model="Debug")
        @spec = spec
        @source_dir = source_dir
        @file_accessor = file_accessor
        @platform = platform
        @build_model = build_model
        @isRootSpec = isRootSpec
        @archs = archs
        @pre_build_shell = pre_build_shell
        @suf_build_shell = suf_build_shell
        @build_permission = build_permission
        @toolchain = toolchain
        #vendored_static_frameworks 只有 xx.framework  需要拼接为 xx.framework/xx by slj
        vendored_static_frameworks = file_accessor.vendored_static_frameworks.map do |framework|
          path = framework
          extn = File.extname  path
          if extn.downcase == '.framework'
            path = File.join(path,File.basename(path, extn))
          end
          path
        end

        @vendored_libraries = (vendored_static_frameworks + file_accessor.vendored_static_libraries).map(&:to_s)
      end

      def build
        defines = compile
        # build_sim_libraries(defines)

        defines
      end

      def lipo_build(defines)
        UI.section("Building static Library #{@spec}") do
          # defines = compile

          # build_sim_libraries(defines)
          output = framework.fwk_path + Pathname.new(treated_framework_name)
          build_static_library_for_ios(output)
          copy_private_headers
          copy_headers
          copy_license
          copy_resources
          copy_info_plist
          copy_dsym
          cp_to_source_dir
        end
        framework
      end

      private

      def cp_to_source_dir
        framework_name = "#{treated_framework_name}.framework"
        target_dir = File.join(CBin::Config::Builder.instance.zip_dir,framework_name)
        FileUtils.rm_rf(target_dir) if File.exist?(target_dir)

        zip_dir = CBin::Config::Builder.instance.zip_dir
        FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)
        `cp -fa #{@platform}/* #{target_dir}`
      end

      #模拟器，目前只支持 debug x86-64
      def build_sim_libraries(defines)
        UI.message 'Building simulator libraries'

        # archs = %w[i386 x86_64]
        archs = ios_architectures_sim
        pre_build_command
        archs.map do |arch|
          xcodebuild(defines, "-sdk iphonesimulator ARCHS=\'#{arch}\' ", "build-#{arch}",@build_model)
        end
        suf_build_command
      end


      def static_libs_in_sandbox(build_dir = 'build')
        file = Dir.glob("#{build_dir}/lib#{target_name}.a")
        unless file
          UI.warn "file no find = #{build_dir}/lib#{target_name}.a"
        end
        file
      end

      def build_static_library_for_ios(output)
        UI.message "Building ios libraries with archs #{ios_architectures}"
        static_libs = static_libs_in_sandbox('build') + static_libs_in_sandbox('build-simulator') + @vendored_libraries
        # if is_debug_model
          ios_architectures.map do |arch|
            static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
          end
          # ios_architectures_sim do |arch|
          #   static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
          # end
        # end

        build_path = Pathname("build")
        build_path.mkpath unless build_path.exist?

        # if is_debug_model
        #   libs = (ios_architectures + ios_architectures_sim) .map do |arch|
        #     library = "build-#{arch}/#{@spec.name}.framework/#{@spec.name}"
        #     library
        #   end
        libs = (ios_architectures) .map do |arch|
          library = "build-#{arch}/#{treated_framework_name}.framework/#{treated_framework_name}"
          library
        end
        # else
        #   libs = ios_architectures.map do |arch|
        #     library = "build/package-#{@spec.name}-#{arch}.a"
        #     # libtool -arch_only arm64 -static -o build/package-armv64.a build/libIMYFoundation.a build-simulator/libIMYFoundation.a
        #     # 从liBFoundation.a 文件中，提取出 arm64 架构的文件，命名为build/package-armv64.a
        #     UI.message "libtool -arch_only #{arch} -static -o #{library} #{static_libs.join(' ')}"
        #     `libtool -arch_only #{arch} -static -o #{library} #{static_libs.join(' ')}`
        #     library
        #   end
        # end
        if libs.length == 1
          UI.message "cp #{libs[0]} #{output}"
          `cp #{libs[0]} #{output}`
        else
          UI.message "lipo -create -output #{output} #{libs.join(' ')}"
          `lipo -create -output #{output} #{libs.join(' ')}`
        end
      end

      def ios_build_options
        "ARCHS=\'#{ios_architectures.join(' ')}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'"
      end

      def ios_architectures
        # >armv7
        #   iPhone4
        #   iPhone4S
        # >armv7s   去掉
        #   iPhone5
        #   iPhone5C
        # >arm64
        #   iPhone5S(以上)
        # >i386
        #   iphone5,iphone5s以下的模拟器
        # >x86_64
        #   iphone6以上的模拟器
        # archs = %w[arm64 armv7]
        # archs = %w[x86_64 arm64 armv7s i386]
        # @vendored_libraries.each do |library|
        #   archs = `lipo -info #{library}`.split & archs
        # end
        archs = @archs.split(",")
        archs
      end

      def ios_architectures_sim

        archs = %w[x86_64]
        # TODO 处理是否需要 i386
        archs
      end

      def compile
        defines = ""
        unless @toolchain.empty? then
          defines += "-toolchain \"#{@toolchain}\""
        end
        defines += "GCC_PREPROCESSOR_DEFINITIONS='$(inherited)'"
        defines += "  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited)' "
        defines += @spec.consumer(@platform).compiler_flags.join(' ')
        # options = ios_build_options
        # if is_debug_model
          archs = ios_architectures
          # archs = %w[arm64 armv7 armv7s]
          pre_build_command
          archs.map do |arch|
            # -fembed-bitcode支持bitcode BUILD_LIBRARY_FOR_DISTRIBUTION=YES 构建向后兼容的framework
            xcodebuild(defines, "ARCHS=\'#{arch}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\' DEBUG_INFORMATION_FORMAT=\'dwarf-with-dsym\' BUILD_LIBRARY_FOR_DISTRIBUTION=YES","build-#{arch}",@build_model)
          end
        suf_build_command
        # else
          # xcodebuild(defines,options)
        # end

        defines
      end

      def is_debug_model
        @build_model == "Debug"
      end

      def target_name
        #区分多平台，如配置了多平台，会带上平台的名字
        # 如libwebp-iOS
        if @spec.available_platforms.count > 1
          "#{@spec.name}-#{Platform.string_name(@spec.consumer(@platform).platform_name)}"
        else
          @spec.name
        end
      end

      # 编译前需执行的的shell脚本
      def pre_build_command
        unless @pre_build_shell.empty? then
          command = "sh #{@pre_build_shell}"
          puts command
          UI.message "command = #{command}"
          output = `#{command}`.lines.to_a

          if $CHILD_STATUS.exitstatus != 0
            raise <<~EOF
            Shell command failed: #{command}
            Output:
            #{output.map { |line| "    #{line}" }.join}
            EOF

            Process.exit
          end
        end
      end

      # 编译后需执行的的shell脚本
      def suf_build_command
        unless @suf_build_shell.empty? then
          command = "sh #{@suf_build_shell}"
          puts command
          UI.message "command = #{command}"
          output = `#{command}`.lines.to_a

          if $CHILD_STATUS.exitstatus != 0
            raise <<~EOF
            Shell command failed: #{command}
            Output:
            #{output.map { |line| "    #{line}" }.join}
            EOF

            Process.exit
          end
        end
      end

      def xcodebuild(defines = '', args = '', build_dir = 'build', build_model = 'Debug')

        unless File.exist?("Pods.xcodeproj") #cocoapods-generate v2.0.0
          command = "#{@build_permission}xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{File.join(File.expand_path("..", build_dir), File.basename(build_dir))} clean build -configuration #{build_model} -target #{target_name} -project ./Pods/Pods.xcodeproj 2>&1"
          puts command
        else
          command = "#{@build_permission}xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{build_dir} clean build -configuration #{build_model} -target #{target_name} -project ./Pods.xcodeproj 2>&1"
          puts command
        end

        UI.message "command = #{command}"
        output = `#{command}`.lines.to_a

        if $CHILD_STATUS.exitstatus != 0
          suf_build_command
          raise <<~EOF
            Build command failed: #{command}
            Output:
            #{output.map { |line| "    #{line}" }.join}
          EOF

          Process.exit
        end
      end

      def copy_private_headers
        private_headers = Array.new
        arch = ios_architectures[0]
        spec_private_header_dir = "./build-#{arch}/#{treated_framework_name}.framework/PrivateHeaders"
        if File.exist?(spec_private_header_dir)
          Dir.chdir(spec_private_header_dir) do
            headers = Dir.glob('*.h')
            headers.each do |h|
              private_headers << Pathname.new(File.join(Dir.pwd,h))
            end
          end

          private_headers.each do |h|
            `ditto #{h} #{framework.private_headers_path}/#{h.basename}`
          end
        end
      end

      def copy_headers
        #走 podsepc中的public_headers
        public_headers = Array.new
        arch = ios_architectures[0]
        spec_header_dir = "./build-#{arch}/#{treated_framework_name}.framework/Headers"
        if File.exist?(spec_header_dir)
          Dir.chdir(spec_header_dir) do
            headers = Dir.glob('*.h')
            headers.each do |h|
              public_headers << Pathname.new(File.join(Dir.pwd,h))
            end
          end
          # end

          # UI.message "Copying public headers #{public_headers.map(&:basename).map(&:to_s)}"

          public_headers.each do |h|
            `ditto #{h} #{framework.headers_path}/#{h.basename}`
          end
        end
        # If custom 'module_map' is specified add it to the framework distribution
        # otherwise check if a header exists that is equal to 'spec.name', if so
        # create a default 'module_map' one using it.
        module_map_dir = "./build-#{arch}/#{treated_framework_name}.framework/Modules/module.modulemap"
        if !@spec.module_map.nil?
          module_map_file = @file_accessor.module_map
          if Pathname(module_map_file).exist?
            module_map = File.read(module_map_file)
          end
        elsif File.exist?(module_map_dir)
          module_map_path = Pathname.new(module_map_dir)
          module_map = File.read(module_map_path)
        elsif public_headers.map(&:basename).map(&:to_s).include?("#{treated_framework_name}.h")
          module_map = <<-MAP
          framework module #{treated_framework_name} {
            umbrella header "#{treated_framework_name}.h"

            export *
            module * { export * }
          }
          MAP
        end

        unless module_map.nil?
          UI.message "Writing module map #{module_map}"
          unless framework.module_map_path.exist?
            framework.module_map_path.mkpath
          end
          File.write("#{framework.module_map_path}/module.modulemap", module_map)
        end

        #swift module
        swift_module_map_dir = "./build-#{arch}/#{treated_framework_name}.framework/Modules/#{treated_framework_name}.swiftmodule"
        if File.exist?(swift_module_map_dir)
          `ditto #{swift_module_map_dir} #{framework.swift_module_path}`
          # 解决module与class名称冲突问题
          # swift_module_dir_path = File.expand_path(framework.swift_module_path)
          #
          # exclude_frameworks = ["Foundation","Swift","UIKit","_Concurrency"]
          # Dir.chdir(swift_module_dir_path) {
          #   if File.exist?("./arm64.swiftinterface")
          #     arr = IO.readlines("arm64.swiftinterface")
          #     arr.map { |item|
          #       if item.include?("import ")
          #         items = item.split(" ")
          #         item_last = items.last
          #         if !exclude_frameworks.include?(item_last)
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\.Method/#{item_last}BDF\\.Method/g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\.#{item_last}/#{item_last}ACE\\.#{item_last}BDF/g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\./#{item_last}ACE\\./g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}ACE\\.//g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}BDF/#{item_last}/g' {} \\;`
          #           `find . -name "*.swiftinterface-e" | xargs rm -rf`
          #         end
          #       end
          #     }
          #   end
          #   if File.exist?("./arm64-apple-ios.swiftinterface")
          #     arr = IO.readlines("arm64-apple-ios.swiftinterface")
          #     arr.map { |item|
          #       if item.include?("import ")
          #         items = item.split(" ")
          #         item_last = items.last
          #         if !exclude_frameworks.include?(item_last)
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\.Method/#{item_last}BDF\\.Method/g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\.#{item_last}/#{item_last}ACE\\.#{item_last}BDF/g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}\\./#{item_last}ACE\\./g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}ACE\\.//g' {} \\;`
          #           `find . -name "*.swiftinterface" -exec sed -i -e 's/#{item_last}BDF/#{item_last}/g' {} \\;`
          #           `find . -name "*.swiftinterface-e" | xargs rm -rf`
          #         end
          #       end
          #     }
          #   end
          # }
        end
      end

      def copy_license
        UI.message 'Copying license'
        license_file = @spec.license[:file] || 'LICENSE'
        `cp "#{license_file}" .` if Pathname(license_file).exist?
      end

      def copy_info_plist
        UI.message 'Copying info.plist'
        info_plist_dir = './build-armv7' if File.exist?('./build-armv7')
        info_plist_dir = './build-arm64' if File.exist?('./build-arm64')
        info_plist_file = "#{info_plist_dir}/#{treated_framework_name}.framework/Info.plist"
        `cp "#{info_plist_file}" #{framework.fwk_path}` if Pathname(info_plist_file).exist?
      end

      def copy_resources
        resource_dir = './build/*.bundle'
        resource_dir = './build-armv7/*.bundle' if File.exist?('./build-armv7')
        resource_dir = './build-arm64/*.bundle' if File.exist?('./build-arm64')

        bundles = Dir.glob(resource_dir)

        bundle_names = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          consumer = spec.consumer(@platform)
          consumer.resource_bundles.keys +
              consumer.resources.map do |r|
                File.basename(r, '.bundle') if File.extname(r) == 'bundle'
              end
        end.compact.uniq

        bundles.select! do |bundle|
          bundle_name = File.basename(bundle, '.bundle')
          bundle_names.include?(bundle_name)
        end

        if bundles.count > 0
          UI.message "Copying bundle files #{bundles}"
          bundle_files = bundles.join(' ')
          `cp -rp #{bundle_files} #{framework.resources_path} 2>&1`
        end
        
        real_source_dir = @source_dir
        unless @isRootSpec
          spec_source_dir = File.join(Dir.pwd,"#{treated_framework_name}")
          unless File.exist?(spec_source_dir)
            spec_source_dir = File.join(Dir.pwd,"Pods/#{treated_framework_name}")
          end
          raise "copy_resources #{spec_source_dir} no exist " unless File.exist?(spec_source_dir)

          real_source_dir = spec_source_dir
        end
        resources = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          expand_paths(real_source_dir, spec.consumer(@platform).resources)
        end.compact.uniq

        if resources.count == 0 && bundles.count == 0
          # framework.delete_resources
          return
        end

        if resources.count > 0
          #把 路径转义。 避免空格情况下拷贝失败
          escape_resource = []
          resources.each do |source|
            escape_resource << Shellwords.join(source)
          end
          UI.message "Copying resources #{escape_resource}"
          `cp -rp #{escape_resource.join(' ')} #{framework.resources_path}`
        end
      end

      def copy_dsym
        arch = ios_architectures[0]
        dsym_file = "./build-#{arch}/#{treated_framework_name}.framework.dSYM"
        if File.exist?(dsym_file)
          `ditto "./build-#{arch}/#{treated_framework_name}.framework.dSYM" "./ios/#{treated_framework_name}.framework.dSYM"`
        end
      end

      def expand_paths(source_dir, path_specs)
        path_specs.map do |path_spec|
          Dir.glob(File.join(source_dir, path_spec))
        end
      end

      def framework
        @framework ||= begin
          framework = Framework.new(treated_framework_name, @platform.name.to_s)
          framework.make
          framework
        end
      end

      def treated_framework_name
        CBin::Config::Builder.instance.treated_framework_name(@spec)
      end

    end
  end
end
