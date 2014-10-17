# encoding:utf-8

require 'net/http'
require 'uri'
require 'lettuce-android/version'

module Lettuce module Android
  module DeviceCommands

    def is_app_installed?(package_name)
      has_app_installed?(package_name)
    end

    def is_app_installed_in_data?(package_name)
      has_app_installed_in_data?(package_name)
    end

    def clear_directory(directory)
      all_files_in_directory_path = [directory.chomp('/'), '/*'].join
      adb "shell rm -r #{all_files_in_directory_path}"
    end

    def device_endpoint action
      URI.join("http://localhost:#{port}", action)
    end

    def dump_window_hierarchy(local_path)
      path_in_device = perform_action('dump_window_hierarchy')
      info "dumping window hierarchy to #{local_path}..."
      adb "pull #{path_in_device} #{local_path}"
    end

    def take_screenshot(local_path)
      path_in_device = '/data/local/tmp/lettuce.png'
      info "saving screenshot to #{local_path}..."
      adb "shell /system/bin/screencap -p #{path_in_device}"
      adb "pull #{path_in_device} #{local_path}"
    end

    def start_lettuce_server
      forwarding_port
      terminate_automation_server
      start_automation_server
    end

    def terminate_lettuce_server
      info "terminating lettuce-server"
      Net::HTTP.post_form device_endpoint('/terminate'), {}
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError
      # Swallow
    end

    def lettuce_server_package
      "lettuce-server-#{Lettuce::Android::VERSION}.jar"
    end

    def lettuce_server_class
      "com.lettuce.android.server.TestRunner"
    end

    def lettuce_server_file
      File.absolute_path(File.join(File.dirname(__FILE__), "../../server/bin/#{lettuce_server_package}"))
    end

    def start_automation_server
      info "starting lettuce-server on the device"
      adb "push #{lettuce_server_file} /data/local/tmp"
      Thread.new do
        adb "shell uiautomator runtest #{lettuce_server_package} -c #{lettuce_server_class}"
      end
      at_exit do
        terminate_honeydew_server
      end
    end

    def forwarding_port
      adb "forward tcp:#{lettuce_server_port} tcp:7120"
    end

    def uninstall_app(package_name)
      adb "uninstall #{package_name}"
    end

    def install_app(apk_location, opts=[])
      adb "install #{opts.join(" ")} #{apk_location}"
    end

    def clear_app_data(package_name)
      adb "shell pm clear #{package_name}"
    end

    def reboot
      adb 'reboot'
    end

    def launch_settings
      adb 'shell am start -n com.android.settings/com.android.settings.Settings'
    end

    def adb(command)
      adb_command = "adb -s #{serial} #{command}"
      info "executing '#{adb_command}'"
      `#{adb_command} 2>/dev/null`.tap do
        if $?.exitstatus != 0
          message = "ADB command '#{command}' failed"
          error message
          raise message
        end
      end
    end

  end

end end
