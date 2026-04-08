function [numberOfDIOChannels, numberOfPFILines] = getNumberOfDIOAndPFITerminalsFromDevice(deviceName)
    % Returns the number of timed DIO channels (port0 lines) and PFI lines.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    %
    % DIO channels = port0 lines capable of timed operation.
    % PFI lines = trigger/timing lines (typically 16 on NI X-series cards).
    if isempty(deviceName) ,
        numberOfDIOChannels = 0 ;
        numberOfPFILines = 0 ;
        return
    end
    try
        devices = daqlist("ni") ;
        
        % Get DIO count from DigitalIO subsystem
        dioRows = devices(strcmp(devices.DeviceID, deviceName) & ...
                          strcmp(devices.SubsystemType, "DigitalIO"), :) ;
        if isempty(dioRows) ,
            numberOfDIOChannels = 0 ;
        else
            % The DigitalIO NumChannels reports total port0 lines for timed operation
            numberOfDIOChannels = dioRows.NumChannels(1) ;
        end
        
        % PFI count: NI X-series cards all have 16 PFI terminals.
        % There's no clean way to query this from the DAQ toolbox, but 16
        % is correct for all NI 63xx cards that WaveSurfer supports.
        if numberOfDIOChannels > 0
            numberOfPFILines = 16 ;
        else
            numberOfPFILines = 0 ;
        end
    catch me %#ok<NASGU>
        numberOfDIOChannels = 0 ;
        numberOfPFILines = 0 ;
    end
end
