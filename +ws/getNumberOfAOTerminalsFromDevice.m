function result = getNumberOfAOTerminalsFromDevice(deviceName)
    % The number of AO channels available.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    if isempty(deviceName) ,
        result = 0 ;
        return
    end
    try
        devices = daqlist("ni") ;
        matchRows = devices(strcmp(devices.DeviceID, deviceName) & ...
                            strcmp(devices.SubsystemType, "AnalogOutput"), :) ;
        if isempty(matchRows) ,
            result = 0 ;
        else
            result = matchRows.NumChannels(1) ;
        end
    catch me %#ok<NASGU>
        result = 0 ;
    end
end
