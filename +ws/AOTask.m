classdef AOTask < handle
    % Analog Output Task using MATLAB's native Data Acquisition Toolbox.
    % Replaces the old +dabs-based implementation.
    %
    % NOTE (Harnett Lab, 09/23/21): Only the first AO terminal (Cmd I) is used.
    % Cmd V is not needed during recordings. This only affects WavesurferModel,
    % not TestPulser.
    
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelCount_ = 0
        DaqDevice_ = []
    end
    
    methods
        function self = AOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                               sampleRate, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone) %#ok<INUSL>
                           
            nChannels = length(terminalIDPerChannel) ;
            self.ChannelCount_ = nChannels ;
            self.SampleRate_ = sampleRate ;
            
            if nChannels > 0
                self.DaqDevice_ = daq("ni") ;
                self.DaqDevice_.Rate = sampleRate ;
                
                % Harnett Lab change: Only use first AO terminal (Cmd I)
                deviceName = deviceNamePerChannel{1} ;
                terminalID = terminalIDPerChannel(1) ;
                channelID = sprintf("ao%d", terminalID) ;
                addoutput(self.DaqDevice_, deviceName, channelID, "Voltage") ;
                
                % Verify rate
                if self.DaqDevice_.Rate ~= sampleRate
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQ sample rate to the desired sampling rate') ;
                end
                
                % Configure triggering
                triggerTerminalName = '' ;
                if isequal(keystoneTaskType, 'ai')
                    triggerTerminalName = sprintf('%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                elseif isequal(keystoneTaskType, 'di')
                    triggerTerminalName = sprintf('%s/di/StartTrigger', keystoneTaskDeviceName) ;
                elseif isequal(keystoneTaskType, 'ao')
                    triggerTerminalName = sprintf('%s/PFI%d', triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                end
                
                if ~isempty(triggerTerminalName)
                    addtrigger(self.DaqDevice_, "Digital", "StartTrigger", ...
                               triggerTerminalName, "External") ;
                end
            else
                self.DaqDevice_ = [] ;
            end
        end
        
        function delete(self)
            if ~isempty(self.DaqDevice_)
                try
                    stop(self.DaqDevice_) ;
                catch
                end
                delete(self.DaqDevice_) ;
            end
            self.DaqDevice_ = [] ;
        end
        
        function start(self)
            if ~isempty(self.DaqDevice_)
                start(self.DaqDevice_) ;
            end
        end
        
        function stop(self)
            if ~isempty(self.DaqDevice_)
                stop(self.DaqDevice_) ;
            end
        end
        
        function disableTrigger(self) %#ok<MANU>
            % With the native daq interface, triggers are configured at creation.
            % To "disable" the trigger, we'd need to recreate the daq object.
            % This method is called when zeroing outputs after stopping a run.
            % For now, we just stop and reconfigure.
            if ~isempty(self.DaqDevice_) && self.DaqDevice_.Running
                stop(self.DaqDevice_) ;
            end
        end
        
        function zeroChannelData(self)
            nChannels = self.ChannelCount_ ;
            nScans = 2 ;
            channelData = zeros(nScans, nChannels) ;
            self.setChannelData(channelData) ;
        end
        
        function setChannelData(self, newValue)
            nChannels = self.ChannelCount_ ;
            if isa(newValue, 'double') && ismatrix(newValue) && (size(newValue, 2) == nChannels)
                if ~isempty(self.DaqDevice_)
                    outputData = newValue ;
                    if size(outputData, 1) < 2
                        outputData = zeros(2, nChannels) ;
                    end
                    outputData(end, :) = 0 ;  % Don't end on nonzero value
                    
                    % Preload the output buffer
                    preload(self.DaqDevice_, outputData) ;
                end
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR double matrix, R the number of channels.') ;
            end
        end
        
        function result = isDone(self)
            if isempty(self.DaqDevice_)
                result = true ;
            else
                result = ~self.DaqDevice_.Running ;
            end            
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end
    
end
