require 'cocoapods/installer/project_cache/target_metadata.rb'
require 'parallel'
require 'cocoapods'
require 'xcodeproj'
require 'cocoapods-fy-bin/native/pod_source_installer'

module Pod
  class Installer
    attr_reader :removed_frameworks
    attr_reader :clean_white_list

    def cache_descriptors
      @cache_descriptors ||= begin
                               cache = Downloader::Cache.new(Config.instance.cache_root + 'Pods')
                               cache_descriptors = cache.cache_descriptors_per_pod
                             end
    end
    # 清除项目中不使用二进制的二进制库 工程目录/Pods/组件名称
    def clean_local_cache
      podfile = Pod::Config.instance.podfile
      title_options = { verbose_prefix: '-> '.red }
      root_specs.sort_by(&:name).each do |spec|
        pod_dir = Pod::Config.instance.sandbox.pod_dir(spec.root.name)
        framework_file = pod_dir + "#{spec.root.name}.framework"
        # 如果framework存在 但不使用二进制 则删除framework
        if pod_dir.exist? && framework_file.exist? && (podfile.use_binaries_selector.nil? || !podfile.use_binaries_selector.call(spec)) && !clean_white_list.include?(spec.root.name)
          title = "Remove Binary Framework #{spec.name} #{spec.version}"
          UI.titled_section(title.red, title_options) do
            @removed_frameworks << spec.root.name
            begin
              FileUtils.rm_rf(pod_dir)
            rescue => err
              puts err
            end
          end
        end
      end
    end

    # 清除本地资源 /Users/dengrui/Library/Caches/CocoaPods/Pods/Release/
    def clean_pod_cache
      clean_white_list = ['Bugly', 'LookinServer']
      podfile = Pod::Config.instance.podfile
      root_specs.sort_by(&:name).each do |spec|
        descriptors = cache_descriptors[spec.root.name]
        if !descriptors.nil?
          descriptors = descriptors.select { |d| d[:version] == spec.version}
          descriptors.each do |d|
            # pod cache 文件名由文件内容的 sha1 组成，由于生成时使用的是 podspec，获取时使用的是 podspec.json 导致生成的目录名不一致
            # Downloader::Request slug
            # cache_descriptors_per_pod 表明，specs_dir 中都是以 .json 形式保存 spec
            slug = d[:slug].dirname + "#{spec.version}-#{spec.checksum[0, 5]}"
            puts slug
            framework_file = slug + "#{spec.root.name}.framework"
            puts framework_file
            if framework_file.exist? && (podfile.use_binaries_selector.nil? || !podfile.use_binaries_selector.call(spec)) && !clean_white_list.include?(spec.root.name)
              begin
                FileUtils.rm(d[:spec_file])
                FileUtils.rm_rf(slug)
              rescue => err
                puts err
              end
            end
          end
        end
      end
    end

    alias old_create_pod_installer create_pod_installer
    def create_pod_installer(pod_name)
      installer = old_create_pod_installer(pod_name)
      installer.installation_options = installation_options
      installer
    end

    alias old_install_pod_sources install_pod_sources
    def install_pod_sources
      @clean_white_list = ['Bugly', 'LookinServer']
      @removed_frameworks = Array.new
      podfile = Pod::Config.instance.podfile
      # 如果不是全局使用 则删除不在列表内的framework二进制缓存
      if !podfile.use_binaries?
        clean_local_cache
        clean_pod_cache
      end

      if installation_options.install_with_multi_threads
        if Pod.match_version?('~> 1.4.0')
          install_pod_sources_for_version_in_1_4_0
        elsif Pod.match_version?('~> 1.5')
          install_pod_sources_for_version_above_1_5_0
        else
          old_install_pod_sources
        end
      else
        old_install_pod_sources
        end
    end

    # rewrite install_pod_sources
    def install_pod_sources_for_version_in_1_4_0
      @installed_specs = []
      pods_to_install = sandbox_state.added | sandbox_state.changed
      title_options = { verbose_prefix: '-> '.green }
      Parallel.each(root_specs.sort_by(&:name), in_threads: 4) do |spec|
        if pods_to_install.include?(spec.name)
          if sandbox_state.changed.include?(spec.name) && sandbox.manifest
            previous = sandbox.manifest.version(spec.name)
            title = "Installing #{spec.name} #{spec.version} (was #{previous})"
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options) do
            create_pod_installer(spec.name)
          end
        end
      end
    end

    def install_pod_sources_for_version_above_1_5_0
      @installed_specs = []
      pods_to_install = sandbox_state.added | sandbox_state.changed | removed_frameworks
      title_options = { verbose_prefix: '-> '.green }
      # 多进程下载，多线程时 log 会显著交叉，多进程好点，但是多进程需要利用文件锁对 cache 进行保护
      # in_processes: 10
      Parallel.each(root_specs.sort_by(&:name), in_threads: 4) do |spec|
        if pods_to_install.include?(spec.name)
          if sandbox_state.changed.include?(spec.name) && sandbox.manifest
            current_version = spec.version
            previous_version = sandbox.manifest.version(spec.name)
            has_changed_version = current_version != previous_version
            current_repo = analysis_result.specs_by_source.detect do |key, values|
              break key if values.map(&:name).include?(spec.name)
            end
            current_repo &&= current_repo.url || current_repo.name
            previous_spec_repo = sandbox.manifest.spec_repo(spec.name)
            has_changed_repo = !previous_spec_repo.nil? && current_repo && (current_repo != previous_spec_repo)
            title = "Installing #{spec.name} #{spec.version}"
            if has_changed_version && has_changed_repo
              title += " (was #{previous_version} and source changed to `#{current_repo}` from `#{previous_spec_repo}`)"
              end
            if has_changed_version && !has_changed_repo
              title += " (was #{previous_version})"
              end
            if !has_changed_version && has_changed_repo
              title += " (source changed to `#{current_repo}` from `#{previous_spec_repo}`)"
              end
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options) do
            create_pod_installer(spec.name)
          end
        end
      end
    end

    alias old_write_lockfiles write_lockfiles
    def write_lockfiles
      old_write_lockfiles
      if File.exist?('Podfile_local')

        project = Xcodeproj::Project.open(config.sandbox.project_path)
        #获取主group
        group = project.main_group
        group.set_source_tree('SOURCE_ROOT')
        #向group中添加 文件引用
        file_ref = group.new_reference(config.sandbox.root + '../Podfile_local')
        #podfile_local排序
        podfile_local_group = group.children.last
        group.children.pop
        group.children.unshift(podfile_local_group)
        #保存
        project.save
      end
    end
  end

  module Downloader
    class Cache
      # 多线程锁
      @@lock = Mutex.new

      # 后面如果要切到进程的话，可以在 cache root 里面新建一个文件
      # 利用这个文件 lock
      # https://stackoverflow.com/questions/23748648/using-fileflock-as-ruby-global-lock-mutex-for-processes

      # rmtree 在多进程情况下可能  Directory not empty @ dir_s_rmdir 错误
      # old_ensure_matching_version 会移除不是同一个 CocoaPods 版本的组件缓存
      alias old_ensure_matching_version ensure_matching_version
      def ensure_matching_version
        @@lock.synchronize { old_ensure_matching_version }
      end
    end
  end
end
