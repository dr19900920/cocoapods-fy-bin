require 'yaml'
require 'cocoapods-fy-bin/native/podfile'
require 'cocoapods-fy-bin/native/podfile_env'
require 'cocoapods/generate'

module CBin
  class Config
    def config_file
      config_file_with_configuration_env(configuration_env)
    end

    def template_hash
      {
          'configuration_env' => { description: '编译环境', default: 'debug', selection: %w[debug release] },
          'code_repo_url' => { description: '源码私有源 Git 地址', default: 'https://gitlab.fuyoukache.com/iosThird/swiftThird/FYSwiftSpecs.git' },
          'binary_repo_url' => { description: '二进制私有源 Git 地址', default: 'https://gitlab.fuyoukache.com/iosThird/swiftThird/fybinaryspecs.git' },
          'binary_download_url' => { description: '二进制下载主机地址，内部会依次传入组件名称、版本、打包模式', default: 'https://mobilepods.fuyoukache.com' },
          # 'binary_type' => { description: '二进制打包类型', default: 'framework', selection: %w[framework library] },
          'download_file_type' => { description: '下载二进制文件类型', default: 'zip', selection: %w[zip tgz tar tbz txz dmg] }
      }
    end

    def config_file_with_configuration_env(configuration_env)
      file = config_debug_iphoneos_file
      if configuration_env == "release"
        file = config_release_iphoneos_file
        puts "\n======  #{configuration_env} 环境 ========"
      elsif configuration_env == "debug"
        file = config_debug_iphoneos_file
        puts "\n======  #{configuration_env} 环境 ========"
      else
        raise "\n=====  #{configuration_env} 参数有误，请检查%w[debug release]===="
      end

      File.expand_path("#{Pod::Config.instance.home_dir}/#{file}")
    end

    def configuration_env
      #如果是debug 再去 podfile的配置文件中获取，确保是正确的， pod update时会用到
      if @configuration_env == "debug" || @configuration_env == nil
        if Pod::Config.instance.podfile
          configuration_env ||= Pod::Config.instance.podfile.configuration_env
        end
        configuration_env ||= "debug"
        @configuration_env = configuration_env
      end
      @configuration_env
    end

    #上传的url
    def binary_upload_url
      binary_download_url
    end

    def set_configuration_env(env)
      @configuration_env = env
    end

    #包含arm64  armv7架构，xcodebuild 是Debug模式
    def config_debug_iphoneos_file
      "bin_debug.yml"
    end
    #包含arm64  armv7架构，xcodebuild 是Release模式
    def config_release_iphoneos_file
      "bin_release.yml"
    end

    def sync_config(config)
      File.open(config_file_with_configuration_env(config['configuration_env']), 'w+') do |f|
        f.write(config.to_yaml)
      end
    end

    def default_config
      @default_config ||= Hash[template_hash.map { |k, v| [k, v[:default]] }]
    end

    private

    def load_config
      if File.exist?(config_file)
        YAML.load_file(config_file)
      else
        default_config
      end
    end

    def config
      @config ||= begin
                    puts "====== cocoapods-fy-bin #{CBin::VERSION} 版本 ======== \n"
                    @config = OpenStruct.new load_config
        validate!
        @config
      end
    end

    def validate!
      template_hash.each do |k, v|
        selection = v[:selection]
        next if !selection || selection.empty?

        config_value = @config.send(k)
        next unless config_value
        unless selection.include?(config_value)
          raise Pod::Informative, "#{k} 字段的值必须限定在可选值 [ #{selection.join(' / ')} ] 内".red
        end
      end
    end

    def respond_to_missing?(method, include_private = false)
      config.respond_to?(method) || super
    end

    def method_missing(method, *args, &block)
      if config.respond_to?(method)
        config.send(method, *args)
      elsif template_hash.keys.include?(method.to_s)
        raise Pod::Informative, "#{method} 字段必须在配置文件 #{config_file} 中设置, 请执行 init 命令配置或手动修改配置文件".red
      else
        super
      end
    end
  end

  def self.config
    @config ||= Config.new
  end


end
