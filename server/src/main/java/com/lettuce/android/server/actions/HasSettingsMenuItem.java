package com.lettuce.android.server.actions;

import android.widget.TextView;
import com.android.uiautomator.core.*;
import com.lettuce.android.server.*;

import java.util.Map;

public class HasSettingsMenuItem extends Action {
    public HasSettingsMenuItem(UiDevice uiDevice) {
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        String menuName = (String) arguments.get("menuName");

        UiScrollable settingsMenu = new UiScrollable(new UiSelector().scrollable(true).focused(true));
        UiObject menuItem = settingsMenu.getChildByText(new UiSelector().className(TextView.class.getName()), menuName);
        return isUiObjectAvailable(menuItem, arguments) ? Result.OK : Result.FAILURE;
    }
}
