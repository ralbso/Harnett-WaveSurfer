classdef FiniteOutputTask < handle
    % Finite-duration output task (analog or digital) using MATLAB's native DAQ Toolbox.
    % Used by TestPulser and Refiller for stimulus output.
    
    properties (Dependent = true, SetAccess = immutable)
        IsAnalog
        IsDigital
        TaskName
        DeviceNames
        TerminalIDs
        IsArmed
        OutputDuration
        IsChannelInTask
    end
    
    properties (Dependent = true)
        SampleRate
        TriggerTerminalName
        TriggerEdge
        ChannelData
    end
    
    properties (Access = protected, Transient = true)
        DaqDevice_ = []
    end
    
    properties (Access = protected)
        IsAnalog_
        SampleRate_ = 20000
        TriggerTerminalName_ = ''
        TriggerEdge_ = []
        IsArmed_ = false
        DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)        
        ChannelData_
        IsOutputBufferSyncedToChannelData_ = false
        IsChannelInTask_ = true(1,0)
    end

    methods
        function self = FiniteOutputTask(taskType, taskName, referenceClockSource, referenceClockRate, ...
                                          deviceNames, terminalIDs, isChannelInTask, sampleRate) %#ok<INUSL>
            nChannels = length(terminalIDs) ;
            self.IsAnalog_ = ~isequal(taskType, 'digital') ;
            self.DeviceNames_ = deviceNames ;
            self.TerminalIDs_ = terminalIDs ;
            self.IsChannelInTask_ = isChannelInTask ;
            self.SampleRate_ = sampleRate ;
            
            if nChannels > 0
                self.DaqDevice_ = daq("ni") ;
                self.DaqDevice_.Rate = sampleRate ;
                
                for i = 1:nChannels
                    deviceName = deviceNames{i} ;
                    terminalID = terminalIDs(i) ;
                    if self.IsAnalog_
                        channelID = sprintf("ao%d", terminalID) ;
                        addoutput(self.DaqDevice_, deviceName, channelID, "Voltage") ;
                    else
                        channelID = sprintf("port0/line%d", terminalID) ;
                        addoutput(self.DaqDevice_, deviceName, channelID, "Digital") ;
                    end
                end
                
                if self.DaqDevice_.Rate ~= sampleRate
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQ sample rate to the desired sampling rate') ;
                end
            else
                self.DaqDevice_ = [] ;
            end
        end
        
        function delete(self)
            if ~isempty(self.DaqDevice_) && isvalid(self.DaqDevice_)
                delete(self.DaqDevice_) ;
            end
            self.DaqDevice_ = [] ;
        end
        
        function start(self)
            if self.IsArmed_ && ~isempty(self.DaqDevice_)
                start(self.DaqDevice_) ;
            end
        end
        
        function stop(self)
            if ~isempty(self.DaqDevice_)
                stop(self.DaqDevice_) ;
            end
        end
        
        function value = get.IsArmed(self)
            value = self.IsArmed_ ;
        end
        
        function value = get.IsAnalog(self)
            value = self.IsAnalog_ ;
        end
        
        function value = get.IsDigital(self)
            value = ~self.IsAnalog_ ;
        end
        
        function value = get.IsChannelInTask(self)
            value = self.IsChannelInTask_ ;
        end
        
        function clearChannelData(self)
            nChannels = length(self.TerminalIDs) ;
            if self.IsAnalog_
                self.ChannelData_ = zeros(0, nChannels) ;  
            else
                self.ChannelData_ = false(0, nChannels) ; 
            end                
            self.IsOutputBufferSyncedToChannelData_ = false ;
        end
        
        function zeroChannelData(self)
            nChannels = length(self.TerminalIDs) ;
            nScans = 2 ;
            if self.IsAnalog_
                self.ChannelData = zeros(nScans, nChannels) ;
            else
                self.ChannelData = false(nScans, nChannels) ;
            end
        end
        
        function value = get.ChannelData(self)
            value = self.ChannelData_ ;
        end
        
        function set.ChannelData(self, value)
            nChannels = length(self.TerminalIDs) ;
            if self.IsAnalog_
                requiredType = 'double' ;
            else
                requiredType = 'logical' ;
            end
            if isa(value, requiredType) && ismatrix(value) && (size(value, 2) == nChannels)
                self.ChannelData_ = value ;
                self.IsOutputBufferSyncedToChannelData_ = false ;
                self.syncOutputBufferToChannelData_() ;
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR matrix, R the number of channels, of type %s.', requiredType) ;
            end
        end
        
        function value = get.OutputDuration(self)
            value = size(self.ChannelData_, 1) * self.SampleRate ;
        end
        
        function out = get.DeviceNames(self)
            out = self.DeviceNames_ ;
        end

        function out = get.TerminalIDs(self)
            out = self.TerminalIDs_ ;
        end
        
        function value = get.SampleRate(self)
            value = self.SampleRate_ ;
        end
        
        function out = get.TaskName(self)
            if isempty(self.DaqDevice_)
                out = '' ;
            else
                out = 'FiniteOutputTask' ;
            end
        end
        
        function set.TriggerTerminalName(self, newValue)
            if isempty(newValue)
                self.TriggerTerminalName_ = '' ;
            elseif ws.isString(newValue)
                self.TriggerTerminalName_ = newValue ;
            else
                error('ws:invalidPropertyValue', 'TriggerTerminalName must be empty or a string') ;
            end
        end
        
        function value = get.TriggerTerminalName(self)
            value = self.TriggerTerminalName_ ;
        end

        function set.TriggerEdge(self, newValue)
            if isempty(newValue)
                self.TriggerEdge_ = [] ;
            elseif ws.isAnEdgeType(newValue)
                self.TriggerEdge_ = newValue ;
            else
                error('ws:invalidPropertyValue', 'TriggerEdge must be empty, ''rising'', or ''falling''') ;
            end            
        end
        
        function value = get.TriggerEdge(self)
            value = self.TriggerEdge_ ;
        end
        
        function arm(self)
            if self.IsArmed_
                return
            end
            if ~isempty(self.DaqDevice_)
                % Configure triggering
                if ~isempty(self.TriggerTerminalName_)
                    addtrigger(self.DaqDevice_, "Digital", "StartTrigger", ...
                               self.TriggerTerminalName_, "External") ;
                end
            end
            self.IsArmed_ = true ;
        end

        function disarm(self)
            if self.IsArmed_
                if ~isempty(self.DaqDevice_)
                    stop(self.DaqDevice_) ;
                end
                self.IsArmed_ = false ;
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
    
    methods (Access = protected)
        function syncOutputBufferToChannelData_(self)
            if self.IsOutputBufferSyncedToChannelData_
                return
            end
            if isempty(self.DaqDevice_)
                return
            end
            
            channelData = self.ChannelData_ ;
            nScansInChannelData = size(channelData, 1) ;            
            if nScansInChannelData < 2
                nChannels = length(self.TerminalIDs) ;
                if self.IsAnalog_
                    outputData = zeros(2, nChannels) ;
                else
                    outputData = false(2, nChannels) ;
                end
            else
                outputData = channelData ;
            end
            
            % Zero the last sample
            if self.IsAnalog_
                outputData(end, :) = 0 ;
            else
                outputData(end, :) = false ;
            end
            
            % Preload into the daq device
            if self.IsAnalog_
                preload(self.DaqDevice_, outputData) ;
            else
                preload(self.DaqDevice_, double(outputData)) ;
            end
            
            self.IsOutputBufferSyncedToChannelData_ = true ;
        end
    end
    
end
