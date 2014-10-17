package com.lettuce.android.server.actions;

import com.android.uiautomator.core.*;
import com.lettuce.android.server.*;

import java.util.Map;

public class IsTextPresent extends Action {
    public IsTextPresent(UiDevice uiDevice) {
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        return isUiObjectAvailable(getUiObject(arguments), arguments) ? Result.OK : Result.FAILURE;
    }
}
