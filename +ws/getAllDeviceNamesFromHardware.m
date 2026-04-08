function deviceNames = getAllDeviceNamesFromHardware()
    % Returns a cell array of NI device names visible to MATLAB.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    try
        devices = daqlist("ni") ;
        if isempty(devices) ,
            deviceNames = cell(1,0) ;
        else
            deviceNames = devices.DeviceID' ;  % row cell array
            % Remove duplicates (daqlist can list subsystems separately)
            deviceNames = unique(deviceNames, 'stable') ;
        end
    catch me
        if contains(me.identifier, 'MATLAB:undefinedVarOrClass') || contains(me.message, 'daqlist')
            warning('ws:noDaqToolbox', ...
                    'Data Acquisition Toolbox not found. No NI devices will be available.') ;
            deviceNames = cell(1,0) ;
        else
            rethrow(me) ;
        end
    end
end
