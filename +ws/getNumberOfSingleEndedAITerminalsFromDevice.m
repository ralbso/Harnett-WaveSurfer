function result = getNumberOfSingleEndedAITerminalsFromDevice(deviceName)
    % The number of AI channels available in single-ended mode.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    if isempty(deviceName) ,
        result = 0 ;
        return
    end
    try
        devices = daqlist("ni") ;
        matchRows = devices(strcmp(devices.DeviceID, deviceName) & ...
                            strcmp(devices.SubsystemType, "AnalogInput"), :) ;
        if isempty(matchRows) ,
            result = 0 ;
        else
            result = matchRows.NumChannels(1) ;
        end
    catch me %#ok<NASGU>
        result = 0 ;
    end
end
