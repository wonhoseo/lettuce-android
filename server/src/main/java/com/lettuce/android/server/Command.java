package com.lettuce.android.server;

import java.util.Map;

public class Command {
    private String action;
    private Map<String, Object> arguments;

    public Command(String action, Map<String, Object> arguments) {
        this.action = action;
        this.arguments = arguments;
    }

    public String getAction() {
        return action;
    }

    public Map<String, Object> getArguments() {
        return arguments;
    }
}
