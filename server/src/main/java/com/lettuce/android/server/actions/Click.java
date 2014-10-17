package com.lettuce.android.server.actions;

import com.android.uiautomator.core.*;
import com.lettuce.android.server.*;

import java.util.Map;

public class Click extends Action {
    public Click(UiDevice uiDevice) {
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        final UiObject uiObject = getUiObject(arguments);

        if (isUiObjectAvailable(uiObject, arguments)) {
            uiObject.click();
            return Result.OK;
        }

        return Result.FAILURE;
    }
}
