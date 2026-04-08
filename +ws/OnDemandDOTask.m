classdef OnDemandDOTask < handle
    % On-demand (untimed) Digital Output Task using MATLAB's native DAQ Toolbox.
    % Used for setting individual digital lines immediately (not clocked).
    
    properties (Dependent = true, SetAccess = immutable)
        TaskName
        DeviceNames
        TerminalIDs
    end
    
    properties (Dependent = true)
        ChannelData  % logical row vector, one element per channel
    end
    
    properties (Access = protected, Transient = true)
        DaqDevice_ = []
    end
    
    properties (Access = protected)
        TaskName_ = ''
        DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)        
        ChannelData_
    end
    
    methods
        function self = OnDemandDOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNames, terminalIDs) %#ok<INUSL>
            nChannels = length(terminalIDs) ;
            self.TaskName_ = taskName ;
            self.DeviceNames_ = deviceNames ;
            self.TerminalIDs_ = terminalIDs ;
            
            if nChannels > 0
                self.DaqDevice_ = daq("ni") ;
                for i = 1:nChannels
                    deviceName = deviceNames{i} ;
                    terminalID = terminalIDs(i) ;
                    channelID = sprintf("port0/line%d", terminalID) ;
                    addoutput(self.DaqDevice_, deviceName, channelID, "Digital") ;
                end
            else
                self.DaqDevice_ = [] ;
            end
        end
        
        function delete(self)
            if ~isempty(self.DaqDevice_) && isvalid(self.DaqDevice_)
                try
                    self.zeroChannelData() ;
                catch
                end
                delete(self.DaqDevice_) ;
            end
            self.DaqDevice_ = [] ;
        end
        
        function start(self) %#ok<MANU>
            % On-demand output doesn't need explicit start/stop
        end
        
        function stop(self) %#ok<MANU>
            % On-demand output doesn't need explicit start/stop
        end
        
        function zeroChannelData(self)
            nChannels = length(self.TerminalIDs) ;
            self.ChannelData = false(1, nChannels) ;
        end
        
        function setChannelDataFancy(self, outputStateIfUntimedForEachDOChannel, isInUntimedDOTaskForEachUntimedDOChannel, isDOChannelTimed)
            isDOChannelUntimed = ~isDOChannelTimed ;
            outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
            outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
            if ~isempty(outputStateForEachChannelInUntimedDOTask)
                self.ChannelData = outputStateForEachChannelInUntimedDOTask ;
            end
        end
            
        function value = get.ChannelData(self)
            value = self.ChannelData_ ;
        end
        
        function set.ChannelData(self, newValue)
            nChannels = length(self.TerminalIDs) ;
            if islogical(newValue) && isrow(newValue) && length(newValue) == nChannels
                self.ChannelData_ = newValue ;
                self.syncOutputToChannelData_() ;
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be a 1x%d logical row vector.', nChannels) ;
            end
        end
        
        function setChannelDataQuicklyAndDirtily(self, newValue)
            % Set channel data with no error checking for minimum latency.
            self.ChannelData_ = newValue ;
            if ~isempty(self.DaqDevice_)
                write(self.DaqDevice_, double(newValue)) ;
            end
        end
        
        function out = get.TerminalIDs(self)
            out = self.TerminalIDs_ ;
        end
        
        function out = get.DeviceNames(self)
            out = self.DeviceNames_ ;
        end
        
        function out = get.TaskName(self)
            out = self.TaskName_ ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end
    
    methods (Access = protected)
        function syncOutputToChannelData_(self)
            if ~isempty(self.DaqDevice_)
                write(self.DaqDevice_, double(self.ChannelData_)) ;
            end
        end
    end
    
end
