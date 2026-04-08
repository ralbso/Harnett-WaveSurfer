classdef DOTask < handle
    % Timed Digital Output Task using MATLAB's native Data Acquisition Toolbox.
    
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelCount_ = 0
        DaqDevice_ = []
    end
    
    methods
        function self = DOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs, ...
                               sampleRate, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone) %#ok<INUSL>
                                    
            nChannels = length(terminalIDs) ;
            self.ChannelCount_ = nChannels ;
            self.SampleRate_ = sampleRate ;
            
            if nChannels > 0
                self.DaqDevice_ = daq("ni") ;
                self.DaqDevice_.Rate = sampleRate ;
                
                for i = 1:nChannels
                    terminalID = terminalIDs(i) ;
                    channelID = sprintf("port0/line%d", terminalID) ;
                    addoutput(self.DaqDevice_, primaryDeviceName, channelID, "Digital") ;
                end
                
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
                    triggerTerminalName = sprintf('%s/ao/StartTrigger', keystoneTaskDeviceName) ;
                elseif isequal(keystoneTaskType, 'do')
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
            if ~isempty(self.DaqDevice_) && self.DaqDevice_.Running
                stop(self.DaqDevice_) ;
            end
        end
        
        function clearChannelData(self)
            nChannels = self.ChannelCount_ ;
            self.setChannelData(false(0, nChannels)) ;
        end
        
        function zeroChannelData(self)
            nChannels = self.ChannelCount_ ;
            self.setChannelData(false(2, nChannels)) ;
        end
        
        function setChannelData(self, value)
            nChannels = self.ChannelCount_ ;
            if isa(value, 'logical') && ismatrix(value) && (size(value, 2) == nChannels)
                if ~isempty(self.DaqDevice_)
                    outputData = value ;
                    if size(outputData, 1) < 2
                        outputData = false(2, nChannels) ;
                    end
                    outputData(end, :) = false ;  % Don't end on nonzero value
                    preload(self.DaqDevice_, double(outputData)) ;
                end
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR logical matrix, R the number of channels.') ;
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
