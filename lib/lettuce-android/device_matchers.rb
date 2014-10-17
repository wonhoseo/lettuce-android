# encoding:utf-8

module Lettuce module Android

  module DeviceMatchers

    def has_app_installed_in_data?(package_name)
      packages_in_data.grep(/#{package_name}/).count > 0
    end

    def has_text?(text)
      perform_assertion :is_text_present, :text => text
    end

    def has_regex_match?(regex)
      perform_assertion :is_regex_match_present, :regex => regex
    end

    def has_element_with_description?(description)
      perform_assertion :is_text_present, :description => description
    end

    def has_edit_text?(text)
      perform_assertion :is_text_present, :text => text, :type => 'EditText'
    end

    def has_textview_text?(text)
      perform_assertion :is_text_present, :text => text, :type => 'TextView'
    end

    def has_text_disappear?(text)
      perform_assertion :is_text_gone, :text => text, :type => 'TextView'
    end

    def has_textview_with_text_and_description?(text, description)
      perform_assertion :is_text_present, :text => text, :description => description, :type => 'TextView'
    end

    def has_button?(button_text)
      perform_assertion :is_button_present, :text => button_text
    end

    def has_child_count? parent_description, child_description, child_count
      child_count_assertion 'equal_to', parent_description, child_description, child_count
    end

    def has_child_count_greater_than? parent_description, child_description, child_count
      child_count_assertion 'greater_than', parent_description, child_description, child_count
    end

    def child_count_assertion count_type, parent_description, child_description, child_count
      assertion_type = "is_child_count_#{count_type}".to_sym
      perform_assertion assertion_type,
                        :parent_description => parent_description,
                        :child_description => child_description,
                        :child_count => child_count
    end

    def has_element_with_nested_text?(parent_description, child_text)
      perform_assertion :is_element_with_nested_text_present,
        :parent_description => parent_description,
         :child_text => child_text
    end

    def has_app_installed?(package_name)
      installed_packages.include?(package_name)
    end

    def is_option_in_setting_enabled?(item_name, option_names)
      perform_assertion :is_option_in_settings_menu_enabled,
        :menuName => item_name, :optionNames => option_names
    end

    def is_option_in_setting_disabled?(item_name, option_names)
      perform_assertion :is_option_in_settings_menu_disabled,
        :menuName => item_name, :optionNames => option_names
    end

    def has_settings_menu_item?(item_name)
      perform_assertion :has_settings_menu_item,
        :menuName => item_name
    end

    private

    def installed_packages
      adb('shell pm list packages').gsub('package:', '').split(/\r\n/)
    end

    def installed_packages_with_path
      adb("shell pm list packages -f").split(/\r\n/)
    end

    def packages_in_data
      installed_packages_with_path.select {|p| p.starts_with? "package:/data/"}
    end

    def packages_in_system
      installed_packages_with_path.select {|p| p.starts_with? "package:/system/"}
    end

  end

end end
