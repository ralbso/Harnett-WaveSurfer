classdef SamplesBuffer < handle
    properties (SetAccess=immutable)
        bufferSizeInScans_
    end
    
    properties
        nAnalogChannels_
        nDigitalChannels_
        analogBuffer_
        digitalBuffer_
        nScansInBuffer_
        timeSinceRunStartAtStartOfBuffer_
    end
    
    methods
        function self = SamplesBuffer(nAnalogChannels, nDigitalChannels, bufferSizeInScans)
            % Analog buffer now stores doubles (voltage data from DAQ Toolbox)
            % instead of int16 (raw ADC counts from the old +dabs interface).
            self.analogBuffer_ = zeros(bufferSizeInScans, nAnalogChannels, 'double') ;
            % Digital buffer stores packed unsigned integers
            if nDigitalChannels <= 8
                digitalType = 'uint8' ;
            elseif nDigitalChannels <= 16
                digitalType = 'uint16' ;
            else
                digitalType = 'uint32' ;
            end
            if nDigitalChannels == 0
                self.digitalBuffer_ = zeros(bufferSizeInScans, 0, digitalType) ;
            else
                self.digitalBuffer_ = zeros(bufferSizeInScans, 1, digitalType) ;
            end
            self.bufferSizeInScans_ = bufferSizeInScans ;
            self.nScansInBuffer_ = 0 ;
            self.nAnalogChannels_ = nAnalogChannels ;
            self.nDigitalChannels_ = nDigitalChannels ;            
        end
        
        function err = store(self, newAnalogData, newDigitalData, timeSinceRunStartAtStartOfNewData)
            nNewScans = size(newAnalogData, 1) ;
            nScansInBufferOriginally = self.nScansInBuffer_ ;
            nScansInBufferOnExit = nNewScans + nScansInBufferOriginally ;
            if nScansInBufferOnExit > self.bufferSizeInScans_
                err = MException('ws:bufferOverrun', ...
                                 'Samples buffer was overrun before it could be emptied') ;
            else
                if nScansInBufferOriginally == 0
                    self.timeSinceRunStartAtStartOfBuffer_ = timeSinceRunStartAtStartOfNewData ;
                end
                if self.nAnalogChannels_ > 0
                    self.analogBuffer_(nScansInBufferOriginally+1:nScansInBufferOnExit, :) = newAnalogData ;
                end
                if self.nDigitalChannels_ > 0
                    self.digitalBuffer_(nScansInBufferOriginally+1:nScansInBufferOnExit, :) = newDigitalData ;
                end
                self.nScansInBuffer_ = nScansInBufferOnExit ;
                err = [] ;
            end            
        end
        
        function [analogData, digitalData, timeSinceRunStartAtStartOfBuffer] = empty(self) 
            nScansInBuffer = self.nScansInBuffer_ ; 
            analogData = self.analogBuffer_(1:nScansInBuffer, :) ; 
            digitalData = self.digitalBuffer_(1:nScansInBuffer, :) ; 
            timeSinceRunStartAtStartOfBuffer = self.timeSinceRunStartAtStartOfBuffer_ ;
            self.nScansInBuffer_ = 0 ;
            self.timeSinceRunStartAtStartOfBuffer_ = [] ;
        end
        
        function result = nScansInBuffer(self)
            result = self.nScansInBuffer_ ;
        end
    end
end
