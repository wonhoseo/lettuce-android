# encoding:utf-8

module Lettuce module Android
  
  class Env  
  
    require 'win32/registry' if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      
    def self.android_home_path
        path_if_android_home(ENV["ANDROID_HOME"]) ||
      if is_windows?
        path_if_android_home(read_registry(::Win32::Registry::HKEY_LOCAL_MACHINE, 'SOFTWARE\\Android SDK Tools', 'Path')) ||
        path_if_android_home("C:\\Android\\android-sdk")
      else
        path_if_android_home(read_attribute_from_monodroid_config('android-sdk', 'path'))
      end
    end
  
    def self.adb_path
      %Q("#{android_home_path}/platform-tools/#{adb_executable}")
    end
    
    def self.path_if_android_home(path)
      path if path && File.exists?(File.join(path, 'platform-tools', adb_executable))
    end
      
    def self.adb_executable
      is_windows? ? 'adb.exe' : 'adb'
    end
  
    def self.is_windows?
      (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    end
    
  end # class Env
  
end end
